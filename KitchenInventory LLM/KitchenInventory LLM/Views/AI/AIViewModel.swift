//
//  AIViewModel.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class AIViewModel: ObservableObject {
    // MARK: - Published State

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var hasStartedChat: Bool = false
    @Published var currentJoke: String = KitchenJokes.jokes.randomElement() ?? ""
    @Published var errorMessage: String?

    // Undo support
    @Published var undoToast: UndoAction?

    // MARK: - Dependencies

    private let apiService = ClaudeAPIService()
    private let model = "claude-haiku-4-5"

    // MARK: - Action Chips

    struct ActionChip: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let prompt: String
    }

    let actionChips: [ActionChip] = [
        ActionChip(icon: "🔍", label: "What's expiring?", prompt: "What items in my kitchen are expiring soon? List them with their expiration dates."),
        ActionChip(icon: "🍳", label: "Recipe ideas", prompt: "Suggest a recipe using ingredients I have that are expiring soonest."),
        ActionChip(icon: "➕", label: "Add items", prompt: "I'd like to add some items to my inventory. What would you like to add?"),
        ActionChip(icon: "🛒", label: "What can I cook?", prompt: "Based on everything in my kitchen right now, what meals can I make without buying anything else?"),
    ]

    // MARK: - Undo

    struct UndoAction: Identifiable {
        let id = UUID()
        let message: String
        let action: () -> Void
    }

    // MARK: - Send Message

    func sendMessage(_ text: String? = nil, modelContext: ModelContext) {
        let messageText = text ?? inputText
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        inputText = ""
        hasStartedChat = true
        errorMessage = nil

        // Rotate joke
        currentJoke = KitchenJokes.jokes.randomElement() ?? ""

        // Add user message
        let userMessage = ChatMessage(role: "user", content: messageText)
        modelContext.insert(userMessage)
        messages.append(userMessage)
        try? modelContext.save()

        // Send to API
        isLoading = true

        Task {
            do {
                guard KeychainHelper.hasAPIKey else {
                    throw KitchenError.noAPIKey
                }

                let systemPrompt = KitchenPromptBuilder.buildSystemPrompt(modelContext: modelContext)
                let messagesPayload = KitchenPromptBuilder.buildMessages(from: messages)
                let tools = ToolRegistry.toolDefinitions

                // Use a background context for tool execution
                let container = modelContext.container

                let result = try await apiService.runToolLoop(
                    initialMessages: messagesPayload,
                    systemPrompt: systemPrompt,
                    tools: tools,
                    model: model,
                    toolExecutor: { @Sendable toolCall in
                        try await MainActor.run {
                            let bgContext = ModelContext(container)
                            bgContext.autosaveEnabled = false
                            let toolResult = try ToolRegistry.execute(toolCall: toolCall, context: bgContext)
                            try bgContext.save()
                            return toolResult
                        }
                    }
                )

                // Add assistant response
                let assistantMessage = ChatMessage(role: "assistant", content: result.text)
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)
                try? modelContext.save()

            } catch let error as KitchenError {
                errorMessage = error.errorDescription
                let errorMsg = ChatMessage(
                    role: "assistant",
                    content: "⚠️ \(error.errorDescription ?? "Something went wrong.")"
                )
                modelContext.insert(errorMsg)
                messages.append(errorMsg)
                try? modelContext.save()

            } catch {
                errorMessage = error.localizedDescription
                let errorMsg = ChatMessage(
                    role: "assistant",
                    content: "⚠️ \(error.localizedDescription)"
                )
                modelContext.insert(errorMsg)
                messages.append(errorMsg)
                try? modelContext.save()
            }

            isLoading = false
        }
    }

    // MARK: - Load History

    func loadHistory(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        if let stored = try? modelContext.fetch(descriptor) {
            messages = stored
            hasStartedChat = !stored.isEmpty
        }
    }

    // MARK: - Clear Chat

    func clearChat(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ChatMessage>()
        if let allMessages = try? modelContext.fetch(descriptor) {
            for msg in allMessages {
                modelContext.delete(msg)
            }
        }
        messages = []
        hasStartedChat = false
        try? modelContext.save()
    }

    // MARK: - Dismiss Undo Toast

    func dismissUndo() {
        undoToast = nil
    }
}
