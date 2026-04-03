//
//  MainTabView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0  // Default to Record tab — voice-first
    @State private var pendingAIPrompt: String?
    @State private var kitchenNavPath = NavigationPath()
    @StateObject private var aiViewModel = AIViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            MicTabView(viewModel: aiViewModel)
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }
                .tag(0)

            AIView(pendingPrompt: $pendingAIPrompt, viewModel: aiViewModel)
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
                .tag(1)

            KitchenView(navigationPath: $kitchenNavPath)
                .tabItem {
                    Label("Kitchen", systemImage: "refrigerator.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .tint(.accent)
        .onChange(of: selectedTab) { _, newTab in
            // Cancel active voice recording when leaving mic tab (tab 0)
            // Don't cancel when arriving at mic tab — it auto-starts on appear
            if newTab != 0 && aiViewModel.voiceSessionState == .voiceMode {
                aiViewModel.cancelVoiceMode()
            }
            // Pop Kitchen back to root when leaving and returning
            kitchenNavPath = NavigationPath()
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToAITab)) { _ in
            withAnimation {
                selectedTab = 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToAITabWithPrompt)) { notification in
            if let prompt = notification.object as? String {
                pendingAIPrompt = prompt
            }
            withAnimation {
                selectedTab = 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToKitchenWithNewItems)) { _ in
            withAnimation {
                selectedTab = 2
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToRecordTab)) { _ in
            withAnimation {
                selectedTab = 0
            }
        }
    }
}

#Preview {
    MainTabView()
}
