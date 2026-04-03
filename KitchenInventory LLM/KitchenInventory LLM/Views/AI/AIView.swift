//
//  AIView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import SwiftUI
import SwiftData

struct AIView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = AIViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if viewModel.hasStartedChat {
                        chatView
                    } else {
                        actionFirstView
                    }

                    // "Having trouble? Try typing instead" fallback
                    if viewModel.showTypingSuggestion {
                        typingSuggestionBanner
                    }

                    inputBar
                }
            }
            .navigationTitle("AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Recording indicator in nav bar
                if viewModel.isRecording {
                    ToolbarItem(placement: .topBarLeading) {
                        RecordingDotView()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            viewModel.clearChat(modelContext: modelContext)
                        } label: {
                            Label("Clear Chat", systemImage: "trash")
                        }

                        NavigationLink {
                            SettingsView()
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .onAppear {
                viewModel.loadHistory(modelContext: modelContext)
            }
            .onDisappear {
                viewModel.teardown()
            }
            .overlay(alignment: .bottom) {
                if let undo = viewModel.undoToast {
                    undoToastView(undo)
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Action-First Layout (Empty State IS the product)

    private var actionFirstView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer()
                    .frame(height: 24)

                // Dad joke card
                jokeCard

                // Big action chips
                VStack(spacing: 12) {
                    ForEach(viewModel.actionChips) { chip in
                        Button {
                            viewModel.sendMessage(chip.prompt, modelContext: modelContext)
                        } label: {
                            HStack(spacing: 12) {
                                Text(chip.icon)
                                    .font(.title3)
                                Text(chip.label)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.textMuted)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.surface1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.accent, lineWidth: 1.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(chip.label)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Chat View

    private var chatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Collapsed chips (horizontal scroll)
                    collapsedChips

                    // Dad joke (small, above messages)
                    jokeCard
                        .padding(.bottom, 8)

                    // Messages
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            typingIndicator
                                .id("typing")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                withAnimation(.easeOut(duration: 0.3)) {
                    if viewModel.isLoading {
                        proxy.scrollTo("typing", anchor: .bottom)
                    } else if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isLoading) {
                if viewModel.isLoading {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Collapsed Action Chips

    private var collapsedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.actionChips) { chip in
                    Button {
                        viewModel.sendMessage(chip.prompt, modelContext: modelContext)
                    } label: {
                        HStack(spacing: 6) {
                            Text(chip.icon)
                                .font(.caption)
                            Text(chip.label)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.surface2)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(chip.label)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Dad Joke Card

    private var jokeCard: some View {
        Text(viewModel.currentJoke)
            .font(.footnote)
            .foregroundColor(.textMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 6) {
                TypingDotsView()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.border, lineWidth: 0.5)
            )
            .clipShape(ChatBubbleShape(isUser: false))
            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)

            Spacer()
        }
    }

    // MARK: - Typing Suggestion Banner

    private var typingSuggestionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.subheadline)
                .foregroundColor(.accent)

            Text("Having trouble? Try typing instead")
                .font(.subheadline)
                .foregroundColor(.textSecondary)

            Spacer()

            Button {
                viewModel.dismissTypingSuggestion()
                isInputFocused = true
            } label: {
                Text("Type")
                    .font(.subheadline.bold())
                    .foregroundColor(.accent)
            }

            Button {
                viewModel.dismissTypingSuggestion()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.textMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.surface2)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            // Recording state: full-width listening indicator
            if viewModel.isRecording {
                listeningBar
            } else {
                // Normal state: mic hero + text field
                HStack(spacing: 12) {
                    // Mic button — LEFT side, hero element
                    Button {
                        viewModel.toggleRecording(modelContext: modelContext)
                    } label: {
                        MicButtonView(isRecording: false)
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Start voice input")

                    // Text field
                    TextField("Ask me anything...", text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.border, lineWidth: 0.5)
                        )
                        .focused($isInputFocused)

                    // Send button (only visible when there's text)
                    if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            viewModel.sendMessage(modelContext: modelContext)
                            isInputFocused = false
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.accent)
                        }
                        .disabled(viewModel.isLoading)
                        .accessibilityLabel("Send message")
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(Color.appBg)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
        .animation(.easeInOut(duration: 0.2), value: viewModel.inputText.isEmpty)
    }

    // MARK: - Listening Bar (replaces input bar when recording)

    private var listeningBar: some View {
        Button {
            viewModel.toggleRecording(modelContext: modelContext)
        } label: {
            HStack(spacing: 14) {
                MicButtonView(isRecording: true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.partialTranscript.isEmpty ? "Listening..." : viewModel.partialTranscript)
                        .font(.body)
                        .foregroundColor(viewModel.partialTranscript.isEmpty ? .textMuted : .textPrimary)
                        .lineLimit(2)

                    if viewModel.partialTranscript.isEmpty {
                        Text("Tap to stop")
                            .font(.caption)
                            .foregroundColor(.textMuted)
                    }
                }

                Spacer()

                // Stop indicator
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.error)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.accent, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityLabel("Stop recording. \(viewModel.partialTranscript.isEmpty ? "Listening" : viewModel.partialTranscript)")
    }

    // MARK: - Undo Toast

    private func undoToastView(_ undo: AIViewModel.UndoAction) -> some View {
        HStack(spacing: 12) {
            Text(undo.message)
                .font(.subheadline)
                .foregroundColor(.white)

            Button("Undo") {
                undo.action()
                viewModel.dismissUndo()
            }
            .font(.subheadline.bold())
            .foregroundColor(.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.textPrimary)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    viewModel.dismissUndo()
                }
            }
        }
    }
}

// MARK: - Mic Button View

struct MicButtonView: View {
    let isRecording: Bool
    @State private var pulseScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isRecording {
                // Pulse ring while recording
                Circle()
                    .fill(Color.error.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .scaleEffect(reduceMotion ? 1.0 : pulseScale)
                    .opacity(reduceMotion ? 0.6 : (pulseScale > 1.2 ? 0.0 : 0.5))

                // Recording state — red circle with white mic
                Circle()
                    .fill(Color.error)
                    .frame(width: 44, height: 44)

                Image(systemName: "mic.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                // Idle state — accent filled circle, prominent
                Circle()
                    .fill(Color.accent)
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.accent.opacity(0.3), radius: 4, x: 0, y: 2)

                Image(systemName: "mic.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 52, height: 52)
        .contentShape(Circle())
        .onChange(of: isRecording) {
            if isRecording && !reduceMotion {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.5
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    pulseScale = 1.0
                }
            }
        }
    }
}

// MARK: - Recording Dot (nav bar indicator)

struct RecordingDotView: View {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(Color.error)
            .frame(width: 8, height: 8)
            .opacity(reduceMotion ? 1.0 : (isAnimating ? 0.3 : 1.0))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            .accessibilityLabel("Recording in progress")
    }
}

// MARK: - Chat Bubble View

struct ChatBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            Text(message.content)
                .font(.body)
                .foregroundColor(isUser ? .white : .textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isUser ? Color.accent : Color.surface1)
                .overlay {
                    if !isUser {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.border, lineWidth: 0.5)
                    }
                }
                .clipShape(ChatBubbleShape(isUser: isUser))
                .shadow(
                    color: isUser ? .clear : .black.opacity(0.08),
                    radius: 3, x: 0, y: 1
                )

            if !isUser { Spacer(minLength: 60) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isUser ? "You" : "AI"): \(message.content)")
    }
}

// MARK: - Chat Bubble Shape

struct ChatBubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let topLeft: CGFloat = isUser ? 16 : 4
        let topRight: CGFloat = isUser ? 4 : 16
        let bottomLeft: CGFloat = 16
        let bottomRight: CGFloat = 16

        return Path { path in
            path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                radius: topRight,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
            path.addArc(
                center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                radius: bottomRight,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                radius: bottomLeft,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
            path.addArc(
                center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                radius: topLeft,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        }
    }
}

// MARK: - Typing Dots Animation

struct TypingDotsView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.textMuted)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .accessibilityLabel("AI is thinking")
    }
}

// MARK: - Settings View (minimal — API key entry)

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var hasKey: Bool = KeychainHelper.hasAPIKey
    @State private var showSavedConfirmation: Bool = false

    var body: some View {
        ZStack {
            Color.appBg
                .ignoresSafeArea()

            List {
                Section {
                    if hasKey {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.success)
                            Text("API key saved")
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Button("Remove") {
                                KeychainHelper.delete(.claudeAPIKey)
                                hasKey = false
                                apiKey = ""
                            }
                            .foregroundColor(.error)
                            .font(.subheadline)
                        }
                    } else {
                        SecureField("Enter Claude API key", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button("Save API Key") {
                            guard !apiKey.isEmpty else { return }
                            let saved = KeychainHelper.save(apiKey, for: .claudeAPIKey)
                            if saved {
                                hasKey = true
                                showSavedConfirmation = true
                                apiKey = ""
                            }
                        }
                        .disabled(apiKey.isEmpty)
                    }
                } header: {
                    Text("Claude API Key")
                } footer: {
                    Text("Your API key is stored securely in the device Keychain and never sent anywhere except Anthropic's API. This key is for development only — the shipping app uses an on-device model.")
                }

                Section {
                    HStack {
                        Text("Model")
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Text("claude-haiku-4-5")
                            .foregroundColor(.textSecondary)
                            .font(.caption)
                    }
                } header: {
                    Text("AI Model")
                }

                Section {
                    HStack {
                        Text("All data stored on-device")
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.success)
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Your inventory data never leaves your device. The only network call is to the Claude API for AI responses.")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("API Key Saved", isPresented: $showSavedConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your Claude API key has been securely saved.")
        }
    }
}

#Preview {
    AIView()
        .modelContainer(for: [
            InventoryItem.self,
            PurchaseHistory.self,
            ChatMessage.self,
            UserSettings.self
        ], inMemory: true)
}
