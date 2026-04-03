//
//  ContentView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        MainTabView()
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
