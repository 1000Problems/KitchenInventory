//
//  ClaudeAPIService.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import Foundation
import SwiftData

actor ClaudeAPIService: LLMService {
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"
    private let maxToolIterations = 5

    // MARK: - LLMService Protocol

    func sendMessage(
        messages: [[String: Any]],
        systemPrompt: String,
        tools: [LLMToolDefinition],
        model: String
    ) async throws -> LLMResponse {
        guard let apiKey = KeychainHelper.retrieve(.claudeAPIKey) else {
            throw KitchenError.noAPIKey
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": messages
        ]

        if !tools.isEmpty {
            let toolsJSON = try tools.map { tool -> [String: Any] in
                let encoder = JSONEncoder()
                let data = try encoder.encode(tool.inputSchema)
                let schema = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                return [
                    "name": tool.name,
                    "description": tool.description,
                    "input_schema": schema
                ]
            }
            body["tools"] = toolsJSON
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KitchenError.networkUnavailable
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw KitchenError.apiError(httpResponse.statusCode, errorBody)
        }

        return try parseResponse(data)
    }

    // MARK: - Tool-Call Loop

    /// Runs the agentic tool-call loop: send → execute tools → append results → repeat (max 5 iterations)
    func runToolLoop(
        initialMessages: [[String: Any]],
        systemPrompt: String,
        tools: [LLMToolDefinition],
        model: String,
        toolExecutor: @Sendable (ToolCall) async throws -> ToolResult
    ) async throws -> (text: String, allToolResults: [ToolResult]) {
        var messages = initialMessages
        var allToolResults: [ToolResult] = []
        var finalText = ""

        for _ in 0..<maxToolIterations {
            let response = try await sendMessage(
                messages: messages,
                systemPrompt: systemPrompt,
                tools: tools,
                model: model
            )

            // Collect any text content
            if !response.textContent.isEmpty {
                finalText = response.textContent
            }

            // If no tool calls, we're done
            guard response.hasToolCalls else {
                break
            }

            // Build the assistant message with content blocks
            var assistantContentBlocks: [[String: Any]] = []

            if !response.textContent.isEmpty {
                assistantContentBlocks.append([
                    "type": "text",
                    "text": response.textContent
                ])
            }

            for toolCall in response.toolCalls {
                assistantContentBlocks.append([
                    "type": "tool_use",
                    "id": toolCall.id,
                    "name": toolCall.name,
                    "input": toolCall.input
                ])
            }

            messages.append([
                "role": "assistant",
                "content": assistantContentBlocks
            ])

            // Execute each tool and collect results
            var toolResultBlocks: [[String: Any]] = []

            for toolCall in response.toolCalls {
                do {
                    let result = try await toolExecutor(toolCall)
                    allToolResults.append(result)
                    toolResultBlocks.append([
                        "type": "tool_result",
                        "tool_use_id": result.toolUseId,
                        "content": result.content
                    ])
                } catch {
                    let errorResult = ToolResult(
                        toolUseId: toolCall.id,
                        content: "Error: \(error.localizedDescription)",
                        isError: true
                    )
                    allToolResults.append(errorResult)
                    toolResultBlocks.append([
                        "type": "tool_result",
                        "tool_use_id": toolCall.id,
                        "content": "Error: \(error.localizedDescription)",
                        "is_error": true
                    ])
                }
            }

            messages.append([
                "role": "user",
                "content": toolResultBlocks
            ])
        }

        return (text: finalText, allToolResults: allToolResults)
    }

    // MARK: - Private Helpers

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw KitchenError.networkUnavailable
            case .timedOut:
                throw KitchenError.apiError(0, "Request timed out")
            default:
                throw KitchenError.networkUnavailable
            }
        }
    }

    private func parseResponse(_ data: Data) throws -> LLMResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KitchenError.parseError
        }

        let stopReason = json["stop_reason"] as? String ?? "end_turn"

        guard let contentBlocks = json["content"] as? [[String: Any]] else {
            throw KitchenError.parseError
        }

        var textParts: [String] = []
        var toolCalls: [ToolCall] = []

        for block in contentBlocks {
            let type = block["type"] as? String ?? ""

            if type == "text", let text = block["text"] as? String {
                textParts.append(text)
            } else if type == "tool_use" {
                let id = block["id"] as? String ?? UUID().uuidString
                let name = block["name"] as? String ?? ""
                let input = block["input"] as? [String: Any] ?? [:]
                toolCalls.append(ToolCall(id: id, name: name, input: input))
            }
        }

        return LLMResponse(
            textContent: textParts.joined(separator: "\n"),
            toolCalls: toolCalls,
            stopReason: stopReason
        )
    }
}
