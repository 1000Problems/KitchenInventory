//
//  SettingsView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/3/26.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var apiKey: String = ""
    @State private var hasKey: Bool = KeychainHelper.hasAPIKey
    @State private var showSavedConfirmation: Bool = false
    @State private var showResetAllConfirmation: Bool = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var showResetComplete: Bool = false

    enum ConnectionStatus {
        case unknown, checking, connected, failed(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg
                    .ignoresSafeArea()

                List {
                    // API Key
                    apiKeySection

                    // AI Model
                    aiModelSection

                    // Inventory Stats
                    inventorySection

                    // Privacy
                    privacySection

                    // Data Management
                    dataSection

                    // About
                    aboutSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("API Key Saved", isPresented: $showSavedConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your Claude API key has been securely saved.")
            }
            .alert("Reset Everything?", isPresented: $showResetAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset All", role: .destructive) {
                    resetAll()
                }
            } message: {
                Text("This will erase all inventory, chat history, and settings. Your API key will be kept. This cannot be undone.")
            }
            .alert("Reset Complete", isPresented: $showResetComplete) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The app has been reset. Restart the app to begin fresh.")
            }
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
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
                        connectionStatus = .unknown
                        HapticsHelper.warning()
                    }
                    .foregroundColor(.error)
                    .font(.subheadline)
                }

                // Connection status
                HStack {
                    switch connectionStatus {
                    case .unknown:
                        Button("Test Connection") {
                            testConnection()
                        }
                        .font(.subheadline)
                        .foregroundColor(.accent)
                    case .checking:
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Testing...")
                            .font(.subheadline)
                            .foregroundColor(.textMuted)
                    case .connected:
                        Image(systemName: "wifi")
                            .foregroundColor(.success)
                        Text("Connected")
                            .font(.subheadline)
                            .foregroundColor(.success)
                    case .failed(let reason):
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.error)
                        Text(reason)
                            .font(.subheadline)
                            .foregroundColor(.error)
                    }
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
                        HapticsHelper.success()
                    }
                }
                .disabled(apiKey.isEmpty)
            }
        } header: {
            Text("Claude API Key")
        } footer: {
            Text("Your API key is stored securely in the device Keychain. This key is for development only — the shipping app uses an on-device model.")
        }
    }

    // MARK: - AI Model Section

    private var aiModelSection: some View {
        Section {
            HStack {
                Text("Model")
                    .foregroundColor(.textPrimary)
                Spacer()
                Text("claude-opus-4-6")
                    .foregroundColor(.textSecondary)
                    .font(.caption)
            }
        } header: {
            Text("AI Model")
        }
    }

    // MARK: - Inventory Stats Section

    private var inventorySection: some View {
        Section {
            inventoryStatsRows
        } header: {
            Text("Inventory")
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section {
            privacyRow(text: "All data stored on-device", icon: "lock.shield.fill")
            privacyRow(text: "No tracking or analytics", icon: "eye.slash.fill")
            privacyRow(text: "No data collection", icon: "hand.raised.fill")
        } header: {
            Text("Privacy")
        } footer: {
            Text("Your inventory data never leaves your device. The only network call is to the Claude API for AI responses.")
        }
    }

    private func privacyRow(text: String, icon: String) -> some View {
        HStack {
            Text(text)
                .foregroundColor(.textPrimary)
            Spacer()
            Image(systemName: icon)
                .foregroundColor(.success)
        }
    }

    // MARK: - Data Management Section

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                showResetAllConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                    Text("Reset All")
                }
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Erases all inventory, chat history, and learned patterns. Your API key is kept.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                    .foregroundColor(.textPrimary)
                Spacer()
                Text("\(appVersion) (\(buildNumber))")
                    .foregroundColor(.textSecondary)
                    .font(.caption)
            }

            HStack {
                Text("Built by")
                    .foregroundColor(.textPrimary)
                Spacer()
                Text("1000Problems")
                    .foregroundColor(.textSecondary)
                    .font(.caption)
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Inventory Stats

    @ViewBuilder
    private var inventoryStatsRows: some View {
        let itemCount = (try? modelContext.fetchCount(FetchDescriptor<InventoryItem>(
            predicate: #Predicate { !$0.isConsumed }
        ))) ?? 0
        let historyCount = (try? modelContext.fetchCount(FetchDescriptor<PurchaseHistory>())) ?? 0

        HStack {
            Text("Active items")
                .foregroundColor(.textPrimary)
            Spacer()
            Text("\(itemCount)")
                .foregroundColor(.textSecondary)
                .font(.subheadline)
        }

        HStack {
            Text("Items tracked")
                .foregroundColor(.textPrimary)
            Spacer()
            Text("\(historyCount)")
                .foregroundColor(.textSecondary)
                .font(.subheadline)
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func testConnection() {
        connectionStatus = .checking

        Task {
            do {
                guard let apiKey = KeychainHelper.retrieve(.claudeAPIKey) else {
                    connectionStatus = .failed("No API key")
                    return
                }

                var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                request.timeoutInterval = 10

                let body: [String: Any] = [
                    "model": "claude-opus-4-6",
                    "max_tokens": 1,
                    "messages": [["role": "user", "content": "hi"]]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (_, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0

                switch status {
                case 200: connectionStatus = .connected
                case 401: connectionStatus = .failed("Invalid key")
                case 429: connectionStatus = .failed("Rate limited")
                default: connectionStatus = .failed("Error \(status)")
                }
            } catch {
                connectionStatus = .failed("Network error")
            }
        }
    }

    private func clearAllData() {
        HapticsHelper.heavy()

        let itemDescriptor = FetchDescriptor<InventoryItem>()
        if let items = try? modelContext.fetch(itemDescriptor) {
            for item in items { modelContext.delete(item) }
        }

        let historyDescriptor = FetchDescriptor<PurchaseHistory>()
        if let history = try? modelContext.fetch(historyDescriptor) {
            for h in history { modelContext.delete(h) }
        }

        let chatDescriptor = FetchDescriptor<ChatMessage>()
        if let messages = try? modelContext.fetch(chatDescriptor) {
            for msg in messages { modelContext.delete(msg) }
        }

        try? modelContext.save()
    }

    private func resetAll() {
        HapticsHelper.heavy()

        // Clear all SwiftData
        clearAllData()

        // Clear user settings (reset onboarding)
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(settingsDescriptor) {
            for s in settings { modelContext.delete(s) }
        }
        try? modelContext.save()

        showResetComplete = true
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [
            InventoryItem.self,
            PurchaseHistory.self,
            ChatMessage.self,
            UserSettings.self
        ], inMemory: true)
}
