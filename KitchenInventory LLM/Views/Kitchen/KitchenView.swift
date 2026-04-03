//
//  KitchenView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import SwiftUI

struct KitchenView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "refrigerator.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accent)

                    Text("Kitchen Dashboard")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)

                    Text("Your inventory, expiring items,\nand storage overview will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Kitchen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    KitchenView()
}
