//
//  MainTabView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 1  // Default to Kitchen tab

    var body: some View {
        TabView(selection: $selectedTab) {
            AIView()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
                .tag(0)

            KitchenView()
                .tabItem {
                    Label("Kitchen", systemImage: "refrigerator.fill")
                }
                .tag(1)
        }
        .tint(.accent)
    }
}

#Preview {
    MainTabView()
}
