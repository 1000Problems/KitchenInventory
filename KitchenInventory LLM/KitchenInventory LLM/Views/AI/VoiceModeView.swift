//
//  VoiceModeView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/3/26.
//

import SwiftData
import SwiftUI

/// Full-screen voice recording overlay. The hero experience of the app.
/// Shows a large animated mic, live transcript, and Done/Cancel controls.
struct VoiceModeView: View {
    @ObservedObject var viewModel: AIViewModel
    let modelContext: ModelContext

    @State private var pulsePhase: CGFloat = 0
    @State private var ringScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Background
            Color.appBg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with cancel
                topBar

                Spacer()

                // Center: animated mic orb
                micOrb
                    .padding(.bottom, 32)

                // Status text
                statusText
                    .padding(.bottom, 24)

                // Live transcript
                transcriptArea

                Spacer()

                // Bottom: Done button
                bottomControls
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulsePhase = 1.0
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                ringScale = 1.3
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                viewModel.cancelVoiceMode()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.surface2)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Cancel voice mode")

            Spacer()

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

            Spacer()

            // Invisible spacer for centering
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Mic Orb

    private var micOrb: some View {
        ZStack {
            // Outer pulse rings
            Circle()
                .fill(Color.accent.opacity(0.06))
                .frame(width: 180, height: 180)
                .scaleEffect(reduceMotion ? 1.0 : ringScale)

            Circle()
                .fill(Color.accent.opacity(0.1))
                .frame(width: 140, height: 140)
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
                .frame(width: 100, height: 100)
                .shadow(color: Color.accent.opacity(0.4), radius: 20, x: 0, y: 8)

            // Mic icon
            Image(systemName: "mic.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(.accentContrast)
        }
        .frame(width: 180, height: 180)
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
                    Text(viewModel.voiceTranscript.isEmpty ? "\"I bought milk today\" or \"Chicken expires April 7th\"" : viewModel.voiceTranscript)
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
        .frame(maxHeight: 200)
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
            // Done button — always enabled; empty transcript just dismisses
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

            // Hint
            Text("Tap Done when you've listed all your items")
                .font(.caption)
                .foregroundColor(.textMuted)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}

// MARK: - Processing Overlay

/// Shown briefly while Claude parses the transcript into items.
struct VoiceProcessingView: View {
    var body: some View {
        ZStack {
            Color.appBg
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.accent)

                Text("Identifying items...")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)

                Text("This usually takes 1-2 seconds")
                    .font(.subheadline)
                    .foregroundColor(.textMuted)
            }
        }
    }
}
