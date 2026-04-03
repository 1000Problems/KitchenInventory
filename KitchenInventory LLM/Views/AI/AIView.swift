//
//  AIView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import SwiftUI

struct AIView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundColor(.accent)

                    Text("AI Assistant")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)

                    Text("Ask me about your kitchen inventory,\nget recipe ideas, or add items.")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("AI")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AIView()
}
