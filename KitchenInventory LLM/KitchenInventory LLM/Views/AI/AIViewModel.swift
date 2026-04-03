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

    // Voice state (legacy single-shot mode)
    @Published var isRecording: Bool = false
    @Published var partialTranscript: String = ""
    @Published var showTypingSuggestion: Bool = false

    // MARK: - Voice Mode State (Option B: continuous recording)

    enum VoiceSessionState: Equatable {
        case idle
        case voiceMode        // Recording, user talking freely
        case processing       // Transcript sent to AI for parsing
        case confirming       // Parsed items shown for review
    }

    @Published var voiceSessionState: VoiceSessionState = .idle
    @Published var voiceTranscript: String = ""
    @Published var parsedItems: [ParsedItem] = []
    @Published var voiceModeError: String?

    var isInVoiceMode: Bool { voiceSessionState != .idle }

    // Quick-add (learned from purchase history)
    @Published var quickAddItems: [PurchaseHistory] = []

    // MARK: - Dependencies

    private let apiService = ClaudeAPIService()
    private let speechService = SpeechService()
    private let itemParser = VoiceItemParser()
    private let model = "claude-haiku-4-5"
    private var currentTask: Task<Void, Never>?
    private var recordingTask: Task<Void, Never>?
    private var voiceModeTask: Task<Void, Never>?
    private var consecutiveVoiceFailures: Int = 0

    // MARK: - Action Chips

    struct ActionChip: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let prompt: String
    }

    let actionChips: [ActionChip] = [
        ActionChip(icon: "🍳", label: "Recipe Ideas", prompt: "Suggest 2-3 quick recipes using ingredients I have, prioritizing items that expire soonest. Keep it short — recipe name, key ingredients, cook time."),
        ActionChip(icon: "⏰", label: "What's Expiring?", prompt: "Show me what's expiring soon. For each item show the name, where it's stored, and how many days left. Group by urgency: expired first, then expiring within 3 days, then within a week. Keep it clean and scannable."),
        ActionChip(icon: "🗑️", label: "Remove Expired", prompt: "Find all expired items in my kitchen and remove them. Tell me what you removed."),
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

    // MARK: - Voice Mode (Option B)

    /// Enter Voice Mode — starts continuous recording, no auto-stop.
    func enterVoiceMode(modelContext: ModelContext) {
        voiceModeTask?.cancel()
        voiceTranscript = ""
        parsedItems = []
        voiceModeError = nil
        voiceSessionState = .voiceMode
        HapticsHelper.success()

        voiceModeTask = Task {
            do {
                // Request permissions if needed
                let (micGranted, speechGranted) = speechService.isFullyAuthorized()
                if !micGranted || !speechGranted {
                    let granted = await speechService.requestPermissions()
                    if !granted {
                        let (newMic, _) = speechService.isFullyAuthorized()
                        voiceModeError = newMic
                            ? (KitchenError.speechUnavailable.errorDescription ?? "Speech recognition unavailable.")
                            : (KitchenError.microphoneDenied.errorDescription ?? "Microphone access denied.")
                        voiceSessionState = .idle
                        return
                    }
                }

                let stream = try await speechService.startContinuousListening()

                for await transcript in stream {
                    guard !Task.isCancelled else { break }
                    voiceTranscript = transcript
                }

                // Stream ended naturally (shouldn't happen in continuous mode unless chaining failed)
                await speechService.stopListening()

            } catch is CancellationError {
                // Cancelled by user tapping Done or Cancel — expected
            } catch {
                voiceModeError = error.localizedDescription
                voiceSessionState = .idle
                HapticsHelper.error()
            }
        }
    }

    /// User tapped Done — stop recording and process the transcript.
    func finishVoiceMode(modelContext: ModelContext) {
        voiceModeTask?.cancel()

        Task {
            await speechService.stopListening()
        }

        let transcript = voiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !transcript.isEmpty else {
            voiceSessionState = .idle
            voiceTranscript = ""
            HapticsHelper.warning()
            return
        }

        voiceSessionState = .processing
        HapticsHelper.tap()

        Task {
            do {
                let items = try await itemParser.parse(transcript: transcript, modelContext: modelContext)

                if items.isEmpty {
                    voiceModeError = "Couldn't identify any items. Try again?"
                    voiceSessionState = .idle
                    HapticsHelper.warning()
                } else {
                    parsedItems = items
                    voiceSessionState = .confirming
                    HapticsHelper.success()
                }
            } catch {
                voiceModeError = "Failed to process: \(error.localizedDescription)"
                voiceSessionState = .idle
                HapticsHelper.error()
            }
        }
    }

    /// Cancel Voice Mode entirely — discard everything.
    func cancelVoiceMode() {
        voiceModeTask?.cancel()
        Task {
            await speechService.stopListening()
        }
        voiceSessionState = .idle
        voiceTranscript = ""
        parsedItems = []
        voiceModeError = nil
    }

    /// Commit all confirmed items to inventory.
    func confirmAndAddItems(modelContext: ModelContext) {
        guard !parsedItems.isEmpty else { return }

        let count = parsedItems.count
        let itemNames = parsedItems.map { $0.name }
        HapticsHelper.success()

        for parsed in parsedItems {
            let item = InventoryItem(
                name: parsed.name,
                category: parsed.category,
                storageLocation: parsed.storage,
                purchaseDate: parsed.purchaseDate,
                estimatedExpiration: parsed.expirationDate,
                quantity: parsed.quantity,
                unit: parsed.unit,
                source: "voice"
            )
            modelContext.insert(item)

            // Compute days for purchase history (relative from purchase date)
            let expDays: Int? = parsed.expirationDate.map {
                Calendar.current.dateComponents([.day], from: parsed.purchaseDate, to: $0).day ?? 7
            }

            // Upsert purchase history
            upsertPurchaseHistory(
                name: parsed.name,
                storage: parsed.storage,
                category: parsed.category,
                expirationDays: expDays,
                context: modelContext
            )
        }

        saveContext(modelContext, label: "voice mode add items")

        // Add a quiet chat record (visible when user opens AI tab)
        let confirmMessage = ChatMessage(role: "assistant", content: "Added \(count) item\(count == 1 ? "" : "s") from voice: \(itemNames.joined(separator: ", "))")
        modelContext.insert(confirmMessage)
        messages.append(confirmMessage)
        hasStartedChat = true
        saveContext(modelContext, label: "voice confirm message")

        // Reset voice state
        voiceSessionState = .idle
        voiceTranscript = ""
        parsedItems = []

        // Refresh quick-add
        refreshQuickAdd(modelContext: modelContext)

        // Switch to Kitchen tab showing just-added items
        NotificationCenter.default.post(name: .switchToKitchenWithNewItems, object: itemNames)
    }

    /// Remove a single item from the parsed list during confirmation.
    func removeParsedItem(_ item: ParsedItem) {
        parsedItems.removeAll { $0.id == item.id }
        if parsedItems.isEmpty {
            voiceSessionState = .idle
        }
    }

    /// Update a parsed item's storage location.
    func updateParsedItemStorage(_ item: ParsedItem, to storage: StorageLocation) {
        guard let index = parsedItems.firstIndex(where: { $0.id == item.id }) else { return }
        parsedItems[index].storage = storage
    }

    /// Update a parsed item's quantity.
    func updateParsedItemQuantity(_ item: ParsedItem, to quantity: Double) {
        guard let index = parsedItems.firstIndex(where: { $0.id == item.id }) else { return }
        parsedItems[index].quantity = max(0.01, quantity)
    }

    // MARK: - Private: Purchase History Upsert

    private func upsertPurchaseHistory(
        name: String,
        storage: StorageLocation,
        category: String,
        expirationDays: Int?,
        context: ModelContext
    ) {
        let canonicalName = name.lowercased().trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<PurchaseHistory>(
            predicate: #Predicate { $0.canonicalName == canonicalName }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.purchaseCount += 1
            existing.lastPurchaseDate = .now
            existing.preferredStorage = storage
            if let days = expirationDays, existing.purchaseCount > 0 {
                let previousTotal = existing.averageExpirationDays * Double(existing.purchaseCount - 1)
                existing.averageExpirationDays = (previousTotal + Double(days)) / Double(existing.purchaseCount)
            }
        } else {
            let history = PurchaseHistory(
                canonicalName: canonicalName,
                preferredStorage: storage,
                averageExpirationDays: Double(expirationDays ?? 7),
                category: category
            )
            context.insert(history)
        }
    }

    // MARK: - Dismiss Undo Toast

    func dismissUndo() {
        undoToast = nil
    }

    // MARK: - Teardown

    func teardown() {
        recordingTask?.cancel()
        voiceModeTask?.cancel()
        Task {
            await speechService.teardown()
        }
    }
}
