//
//  MicTabView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/3/26.
//

import SwiftData
import SwiftUI

/// Dedicated Mic tab — the hero entry point of the app.
/// Auto-starts recording on appear. Shows live transcript, Done/Cancel.
/// Processing and confirmation stages use a fullScreenCover overlay.
struct MicTabView: View {
    @ObservedObject var viewModel: AIViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var pulsePhase: CGFloat = 0
    @State private var ringScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top: "Try saying" hints + recording indicator
                    topSection
                        .padding(.top, 12)

                    Spacer()

                    // Center: animated mic orb
                    micOrb
                        .padding(.bottom, 20)

                    // Status text
                    statusText
                        .padding(.bottom, 20)

                    // Live transcript
                    transcriptArea

                    Spacer()

                    // Bottom: Done button
                    bottomControls
                }
            }
            .navigationTitle("Record")
            .navigationBarTitleDisplayMode(.inline)
            // Processing + Confirmation overlays
            .fullScreenCover(isPresented: postRecordingBinding) {
                postRecordingOverlay
            }
            .alert("Voice Mode", isPresented: voiceErrorBinding) {
                Button("OK", role: .cancel) {
                    viewModel.voiceModeError = nil
                }
            } message: {
                Text(viewModel.voiceModeError ?? "Something went wrong.")
            }
            .onAppear {
                startRecordingIfNeeded()
                startAnimations()
            }
            .onDisappear {
                // Cancel recording if user switches tabs
                if viewModel.voiceSessionState == .voiceMode {
                    viewModel.cancelVoiceMode()
                }
            }
        }
    }

    // MARK: - Auto-Start

    private func startRecordingIfNeeded() {
        guard viewModel.voiceSessionState == .idle else { return }
        viewModel.enterVoiceMode(modelContext: modelContext)
    }

    private func startAnimations() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulsePhase = 1.0
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            ringScale = 1.3
        }
    }

    // MARK: - Top Section (hints + recording dot)

    private var topSection: some View {
        VStack(spacing: 10) {
            // Recording indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.error)
                    .frame(width: 8, height: 8)
                    .opacity(reduceMotion ? 1.0 : (pulsePhase > 0.5 ? 0.3 : 1.0))

                Text("Recording")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.textSecondary)
            }
            .padding(.bottom, 4)

            // Hint examples
            hintSection
        }
    }

    // MARK: - Hint Section

    private var hintSection: some View {
        VStack(spacing: 8) {
            Text("Try saying")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.textSecondary)

            VStack(spacing: 8) {
                hintExample(icon: "cart.fill", text: "I bought milk and eggs today", color: .accent)
                hintExample(icon: "clock", text: "Chicken expires April 7th", color: .warning)
            }
        }
        .padding(.horizontal, 20)
    }

    private func hintExample(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)

            Text("\"\(text)\"")
                .font(.subheadline)
                .foregroundColor(.textPrimary)
                .italic()

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Mic Orb (recording state — no tap action needed)

    private var micOrb: some View {
        ZStack {
            // Outer pulse rings
            Circle()
                .fill(Color.accent.opacity(0.06))
                .frame(width: 160, height: 160)
                .scaleEffect(reduceMotion ? 1.0 : ringScale)

            Circle()
                .fill(Color.accent.opacity(0.1))
                .frame(width: 120, height: 120)
                .scaleEffect(reduceMotion ? 1.0 : (ringScale * 0.9))

            // Main orb
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accent, Color.accent.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .shadow(color: Color.accent.opacity(0.4), radius: 20, x: 0, y: 8)

            // Mic icon
            Image(systemName: "mic.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(.accentContrast)
        }
        .frame(width: 160, height: 160)
    }

    // MARK: - Status Text

    private var statusText: some View {
        Group {
            if viewModel.voiceTranscript.isEmpty {
                Text("Start talking...")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.textMuted)
            } else {
                Text("Listening")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.accent)
            }
        }
    }

    // MARK: - Transcript Area

    private var transcriptArea: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    Text(viewModel.voiceTranscript.isEmpty
                         ? "\"I bought milk today\" or \"Chicken expires April 7th\""
                         : viewModel.voiceTranscript)
                        .font(.body)
                        .foregroundColor(viewModel.voiceTranscript.isEmpty ? .textMuted : .textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("transcript")
                }
                .padding(.horizontal, 24)
                .onChange(of: viewModel.voiceTranscript) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("transcript", anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxHeight: 180)
        .background(Color.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.border, lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            Button {
                if viewModel.voiceTranscript.isEmpty {
                    viewModel.cancelVoiceMode()
                } else {
                    viewModel.finishVoiceMode(modelContext: modelContext)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.voiceTranscript.isEmpty ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 22))
                    Text(viewModel.voiceTranscript.isEmpty ? "Cancel" : "Done")
                        .font(.headline)
                }
                .foregroundColor(.accentContrast)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .accessibilityLabel(viewModel.voiceTranscript.isEmpty ? "Cancel recording" : "Done recording")

            Text("Tap Done when you've listed all your items")
                .font(.caption)
                .foregroundColor(.textMuted)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Bindings

    /// Only show fullScreenCover for processing + confirming (NOT voiceMode — that's inline now)
    private var postRecordingBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.voiceSessionState == .processing ||
                viewModel.voiceSessionState == .confirming
            },
            set: { if !$0 { viewModel.cancelVoiceMode() } }
        )
    }

    private var voiceErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.voiceModeError != nil },
            set: { if !$0 { viewModel.voiceModeError = nil } }
        )
    }

    // MARK: - Post-Recording Overlay

    @ViewBuilder
    private var postRecordingOverlay: some View {
        switch viewModel.voiceSessionState {
        case .processing:
            VoiceProcessingView()
        case .confirming:
            VoiceConfirmationView(viewModel: viewModel, modelContext: modelContext)
        default:
            Color.appBg.ignoresSafeArea()
        }
    }
}

#Preview {
    MicTabView(viewModel: AIViewModel())
        .modelContainer(for: [
            InventoryItem.self,
            PurchaseHistory.self,
            ChatMessage.self,
            UserSettings.self
        ], inMemory: true)
}
