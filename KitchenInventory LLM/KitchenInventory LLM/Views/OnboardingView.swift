//
//  OnboardingView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/3/26.
//

import AVFoundation
import Speech
import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    let onComplete: () -> Void

    @State private var currentPage: Int = 0
    @State private var micPermissionGranted: Bool = false
    @State private var speechPermissionGranted: Bool = false

    private let totalPages = 3

    var body: some View {
        ZStack {
            Color.appBg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Color.accent : Color.surface3)
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.25), value: currentPage)
                    }
                }
                .padding(.top, 20)

                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    permissionsPage.tag(1)
                    readyPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Bottom button
                Button {
                    if currentPage < totalPages - 1 {
                        currentPage += 1
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    Text(currentPage == totalPages - 1 ? "Get Started" : "Continue")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)

                if currentPage > 0 && currentPage < totalPages - 1 {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(.subheadline)
                    .foregroundColor(.textMuted)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundColor(.accent)

            VStack(spacing: 12) {
                Text("Your AI Kitchen Assistant")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Talk to your kitchen. Add items by voice,\ntrack what's expiring, get recipe ideas\nfrom what you have.")
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            // Feature highlights
            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "mic.fill", color: .accent, title: "Voice-first", description: "Just say what you bought")
                featureRow(icon: "clock.badge.exclamationmark", color: .warning, title: "Expiration alerts", description: "Never waste food again")
                featureRow(icon: "brain.head.profile.fill", color: .appPurple, title: "Learns your habits", description: "Gets smarter with every purchase")
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Page 2: Permissions

    private var permissionsPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "mic.badge.plus")
                .font(.system(size: 56))
                .foregroundColor(.accent)

            VStack(spacing: 12) {
                Text("Enable Voice Input")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)

                Text("Voice is the fastest way to add items.\nWe need microphone and speech\nrecognition access.")
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            VStack(spacing: 12) {
                permissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    granted: micPermissionGranted
                )
                permissionRow(
                    icon: "waveform",
                    title: "Speech Recognition",
                    granted: speechPermissionGranted
                )
            }
            .padding(.horizontal, 32)

            Button {
                requestPermissions()
            } label: {
                Text(micPermissionGranted && speechPermissionGranted ? "Permissions Granted" : "Grant Permissions")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(micPermissionGranted && speechPermissionGranted ? .success : .accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        (micPermissionGranted && speechPermissionGranted ? Color.success : Color.accent)
                            .opacity(0.12)
                    )
                    .clipShape(Capsule())
            }
            .disabled(micPermissionGranted && speechPermissionGranted)

            Spacer()

            Text("You can always change this in\nSettings > Privacy")
                .font(.caption)
                .foregroundColor(.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .onAppear {
            checkCurrentPermissions()
        }
    }

    // MARK: - Page 3: Ready

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.success)

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)

                Text("Tap the mic and say something like:\n\"I bought milk, eggs, and chicken\"")
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            // Privacy callout
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundColor(.success)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Your data stays on your device")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.textPrimary)
                    Text("No tracking, no analytics, no cloud storage")
                        .font(.caption)
                        .foregroundColor(.textMuted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Components

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
    }

    private func permissionRow(icon: String, title: String, granted: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(granted ? .success : .textMuted)
                .frame(width: 32, height: 32)
                .background((granted ? Color.success : Color.textMuted).opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.subheadline)
                .foregroundColor(.textPrimary)

            Spacer()

            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(granted ? .success : .textMuted)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Permissions

    private func checkCurrentPermissions() {
        micPermissionGranted = AVAudioApplication.shared.recordPermission == .granted
        speechPermissionGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    private func requestPermissions() {
        // Request mic first, then speech
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                micPermissionGranted = granted
                // Then request speech
                SFSpeechRecognizer.requestAuthorization { status in
                    DispatchQueue.main.async {
                        speechPermissionGranted = status == .authorized
                    }
                }
            }
        }
    }

    // MARK: - Complete

    private func completeOnboarding() {
        // Save onboarding state
        let descriptor = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(descriptor).first {
            settings.onboardingComplete = true
        } else {
            let settings = UserSettings(onboardingComplete: true)
            modelContext.insert(settings)
        }
        try? modelContext.save()

        onComplete()
    }
}

#Preview {
    OnboardingView {
        print("Onboarding complete")
    }
    .modelContainer(for: UserSettings.self, inMemory: true)
}
