//
//  ContentView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showOnboarding: Bool = true

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showOnboarding = false
                    }
                }
                .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            checkOnboardingStatus()
        }
    }

    private func checkOnboardingStatus() {
        let descriptor = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(descriptor).first,
           settings.onboardingComplete {
            showOnboarding = false
        } else {
            showOnboarding = true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            InventoryItem.self,
            PurchaseHistory.self,
            ChatMessage.self,
            UserSettings.self
        ], inMemory: true)
}
