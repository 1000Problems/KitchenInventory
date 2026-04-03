//
//  MainTabView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0  // Default to AI tab — the AI IS the product
    @State private var pendingAIPrompt: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            AIView(pendingPrompt: $pendingAIPrompt)
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
                .tag(0)

            KitchenView()
                .tabItem {
                    Label("Kitchen", systemImage: "refrigerator.fill")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(.accent)
        .onReceive(NotificationCenter.default.publisher(for: .switchToAITab)) { _ in
            withAnimation {
                selectedTab = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToAITabWithPrompt)) { notification in
            if let prompt = notification.object as? String {
                pendingAIPrompt = prompt
            }
            withAnimation {
                selectedTab = 0
            }
        }
    }
}

#Preview {
    MainTabView()
}
