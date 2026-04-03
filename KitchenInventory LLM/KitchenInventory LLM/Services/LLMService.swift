//
//  LLMService.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import Foundation

// MARK: - LLM Response Types

struct LLMMessage: Codable {
    let role: String
    let content: String
}

struct LLMToolDefinition: Codable {
    let name: String
    let description: String
    let inputSchema: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

struct LLMResponse: @unchecked Sendable {
    let textContent: String
    let toolCalls: [ToolCall]
    let stopReason: String

    var hasToolCalls: Bool { !toolCalls.isEmpty }
}

struct ToolCall: @unchecked Sendable {
    let id: String
    let name: String
    let input: [String: Any]
}

struct ToolResult: @unchecked Sendable {
    let toolUseId: String
    let content: String
    let isError: Bool
}

// MARK: - AnyCodable (for flexible JSON)

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = arrayVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let val as Int: try container.encode(val)
        case let val as Double: try container.encode(val)
        case let val as Bool: try container.encode(val)
        case let val as String: try container.encode(val)
        case let val as [Any]: try container.encode(val.map { AnyCodable($0) })
        case let val as [String: Any]: try container.encode(val.mapValues { AnyCodable($0) })
        default: try container.encodeNil()
        }
    }
}

// MARK: - LLMService Protocol

protocol LLMService {
    /// Send a message with optional tool definitions
    func sendMessage(
        messages: [[String: Any]],
        systemPrompt: String,
        tools: [LLMToolDefinition],
        model: String
    ) async throws -> LLMResponse
}
