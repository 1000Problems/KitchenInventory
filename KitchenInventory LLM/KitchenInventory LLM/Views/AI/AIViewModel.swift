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

    // Voice state
    @Published var isRecording: Bool = false
    @Published var partialTranscript: String = ""
    @Published var showTypingSuggestion: Bool = false

    // Quick-add (learned from purchase history)
    @Published var quickAddItems: [PurchaseHistory] = []

    // MARK: - Dependencies

    private let apiService = ClaudeAPIService()
    private let speechService = SpeechService()
    private let model = "claude-opus-4-6"
    private var currentTask: Task<Void, Never>?
    private var recordingTask: Task<Void, Never>?
    private var consecutiveVoiceFailures: Int = 0

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

        // Cancel any in-flight request
        currentTask?.cancel()

        inputText = ""
        partialTranscript = ""
        hasStartedChat = true
        errorMessage = nil
        HapticsHelper.tap()

        // Rotate joke
        currentJoke = KitchenJokes.jokes.randomElement() ?? ""

        // Add user message
        let userMessage = ChatMessage(role: "user", content: messageText)
        modelContext.insert(userMessage)
        messages.append(userMessage)
        saveContext(modelContext, label: "user message")

        // Send to API
        isLoading = true

        currentTask = Task {
            do {
                try Task.checkCancellation()

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

                try Task.checkCancellation()

                // Add assistant response
                let assistantMessage = ChatMessage(role: "assistant", content: result.text)
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)
                saveContext(modelContext, label: "assistant response")

            } catch is CancellationError {
                // Task was cancelled by a new message — silently stop
            } catch let error as KitchenError {
                errorMessage = error.errorDescription
                addErrorMessage(error.errorDescription ?? "Something went wrong.", modelContext: modelContext)
            } catch {
                errorMessage = error.localizedDescription
                addErrorMessage(error.localizedDescription, modelContext: modelContext)
            }

            isLoading = false
        }
    }

    // MARK: - Voice Input

    /// Toggles recording on/off. When recording stops, sends the transcribed text.
    func toggleRecording(modelContext: ModelContext) {
        if isRecording {
            stopRecording(sendMessage: true, modelContext: modelContext)
        } else {
            startRecording(modelContext: modelContext)
        }
    }

    private func startRecording(modelContext: ModelContext) {
        recordingTask?.cancel()
        partialTranscript = ""
        showTypingSuggestion = false

        recordingTask = Task {
            // Request permissions if needed
            let (micGranted, speechGranted) = speechService.isFullyAuthorized()
            if !micGranted || !speechGranted {
                let granted = await speechService.requestPermissions()
                if !granted {
                    let (newMic, _) = speechService.isFullyAuthorized()
                    if !newMic {
                        addErrorMessage(KitchenError.microphoneDenied.errorDescription ?? "Microphone access denied.", modelContext: modelContext)
                    } else {
                        addErrorMessage(KitchenError.speechUnavailable.errorDescription ?? "Speech recognition unavailable.", modelContext: modelContext)
                    }
                    return
                }
            }

            do {
                isRecording = true
                HapticsHelper.success()
                let stream = try await speechService.startListening()

                var lastTranscript = ""
                for await transcript in stream {
                    guard !Task.isCancelled else { break }
                    partialTranscript = transcript
                    inputText = transcript
                    lastTranscript = transcript
                }

                // Stream ended — always clean up the audio engine
                await speechService.stopListening()

                guard !Task.isCancelled else {
                    isRecording = false
                    return
                }

                isRecording = false

                if lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // No speech detected — count as a failure
                    consecutiveVoiceFailures += 1
                    print("[Voice] No speech detected. Failure count: \(consecutiveVoiceFailures)")
                    if consecutiveVoiceFailures >= 2 {
                        showTypingSuggestion = true
                    }
                    partialTranscript = ""
                    inputText = ""
                } else {
                    // Success — reset failure counter and send
                    consecutiveVoiceFailures = 0
                    sendMessage(lastTranscript, modelContext: modelContext)
                }

            } catch {
                await speechService.stopListening()
                isRecording = false
                consecutiveVoiceFailures += 1
                print("[Voice] Error: \(error.localizedDescription). Failure count: \(consecutiveVoiceFailures)")
                if consecutiveVoiceFailures >= 2 {
                    showTypingSuggestion = true
                }

                HapticsHelper.error()
                if let kitchenErr = error as? KitchenError {
                    addErrorMessage(kitchenErr.errorDescription ?? "Voice error.", modelContext: modelContext)
                }
            }
        }
    }

    func stopRecording(sendMessage shouldSend: Bool, modelContext: ModelContext) {
        Task {
            await speechService.stopListening()
        }
        isRecording = false

        if shouldSend && !partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            consecutiveVoiceFailures = 0
            let text = partialTranscript
            partialTranscript = ""
            sendMessage(text, modelContext: modelContext)
        } else {
            partialTranscript = ""
            inputText = ""
        }
    }

    /// Dismiss the "try typing" suggestion
    func dismissTypingSuggestion() {
        showTypingSuggestion = false
        consecutiveVoiceFailures = 0
    }

    // MARK: - Private Helpers

    private func addErrorMessage(_ text: String, modelContext: ModelContext) {
        let errorMsg = ChatMessage(role: "assistant", content: "⚠️ \(text)")
        modelContext.insert(errorMsg)
        messages.append(errorMsg)
        saveContext(modelContext, label: "error message")
    }

    private func saveContext(_ context: ModelContext, label: String) {
        do {
            try context.save()
        } catch {
            print("[KitchenInventory] Failed to save \(label): \(error.localizedDescription)")
            errorMessage = "Failed to save data. Please try again."
        }
    }

    // MARK: - Load History

    func loadHistory(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        do {
            let stored = try modelContext.fetch(descriptor)
            messages = stored
            hasStartedChat = !stored.isEmpty
        } catch {
            print("[KitchenInventory] Failed to load chat history: \(error.localizedDescription)")
            messages = []
            hasStartedChat = false
        }

        // Load quick-add items from purchase history
        refreshQuickAdd(modelContext: modelContext)
    }

    // MARK: - Quick-Add

    func refreshQuickAdd(modelContext: ModelContext) {
        quickAddItems = ExpirationLearner.quickAddItems(limit: 8, context: modelContext)
    }

    /// Sends a quick-add message for a frequently purchased item
    func quickAdd(_ item: PurchaseHistory, modelContext: ModelContext) {
        let prompt = "Add \(item.canonicalName) to my \(item.preferredStorage.displayName.lowercased())"
        sendMessage(prompt, modelContext: modelContext)
    }

    // MARK: - Clear Chat

    func clearChat(modelContext: ModelContext) {
        currentTask?.cancel()
        recordingTask?.cancel()
        isLoading = false
        isRecording = false
        partialTranscript = ""

        let descriptor = FetchDescriptor<ChatMessage>()
        do {
            let allMessages = try modelContext.fetch(descriptor)
            for msg in allMessages {
                modelContext.delete(msg)
            }
        } catch {
            print("[KitchenInventory] Failed to fetch messages for clear: \(error.localizedDescription)")
        }
        messages = []
        hasStartedChat = false
        saveContext(modelContext, label: "clear chat")
    }

    // MARK: - Dismiss Undo Toast

    func dismissUndo() {
        undoToast = nil
    }

    // MARK: - Teardown

    func teardown() {
        recordingTask?.cancel()
        Task {
            await speechService.teardown()
        }
    }
}
