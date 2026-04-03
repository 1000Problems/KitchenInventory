//
//  VoiceConfirmationView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/3/26.
//

import SwiftUI
import SwiftData

/// Confirmation screen shown after Voice Mode parses the transcript.
/// Each parsed item is displayed as an editable card with storage pills,
/// quantity stepper, purchase date buttons, and swipe-to-remove.
struct VoiceConfirmationView: View {
    @ObservedObject var viewModel: AIViewModel
    let modelContext: ModelContext

    var body: some View {
        ZStack {
            Color.appBg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerBar

                // Item count summary
                summaryBar

                // Item list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.parsedItems) { item in
                            ParsedItemCard(
                                item: item,
                                onStorageChange: { storage in
                                    viewModel.updateParsedItemStorage(item, to: storage)
                                },
                                onRemove: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        viewModel.removeParsedItem(item)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100) // Space for bottom button
                }

                Spacer(minLength: 0)
            }

            // Floating Add All button
            VStack {
                Spacer()
                addAllButton
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
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
            .accessibilityLabel("Cancel")

            Spacer()

            Text("Review Items")
                .font(.headline)
                .foregroundColor(.textPrimary)

            Spacer()

            // Re-record button
            Button {
                viewModel.cancelVoiceMode()
                // Small delay to let state reset, then re-enter
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    viewModel.enterVoiceMode(modelContext: modelContext)
                }
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accent)
                    .frame(width: 36, height: 36)
                    .background(Color.accent.opacity(0.12))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Re-record")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Summary

    private var summaryBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.success)

            Text("\(viewModel.parsedItems.count) item\(viewModel.parsedItems.count == 1 ? "" : "s") found")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.textPrimary)

            Spacer()

            // Storage breakdown
            let counts = storageCounts
            ForEach(StorageLocation.allCases) { loc in
                if let count = counts[loc], count > 0 {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.storageColor(loc.rawValue))
                            .frame(width: 8, height: 8)
                        Text("\(count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.surface2)
    }

    private var storageCounts: [StorageLocation: Int] {
        var counts: [StorageLocation: Int] = [:]
        for item in viewModel.parsedItems {
            counts[item.storage, default: 0] += 1
        }
        return counts
    }

    // MARK: - Add All Button

    private var addAllButton: some View {
        Button {
            viewModel.confirmAndAddItems(modelContext: modelContext)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                Text("Add All \(viewModel.parsedItems.count) Items")
                    .font(.headline)
            }
            .foregroundColor(.accentContrast)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accent)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.accent.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [Color.appBg.opacity(0), Color.appBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)
            .offset(y: -40),
            alignment: .top
        )
        .accessibilityLabel("Add all \(viewModel.parsedItems.count) items to inventory")
    }
}

// MARK: - Parsed Item Card

struct ParsedItemCard: View {
    let item: ParsedItem
    let onStorageChange: (StorageLocation) -> Void
    let onRemove: () -> Void

    private var expirationLabel: String? {
        guard let date = item.expirationDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        if days < 0 { return "Expired \(abs(days))d ago" }
        if days == 0 { return "Expires today" }
        if days == 1 { return "Expires tomorrow" }
        return "Expires in \(days)d — \(DateHelper.shortDate(date))"
    }

    private var expirationColor: Color {
        guard let date = item.expirationDate else { return .textMuted }
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        if days < 0 { return .error }
        if days <= 3 { return .error }
        if days <= 7 { return .warning }
        return .success
    }

    private var purchaseLabel: String {
        if Calendar.current.isDateInToday(item.purchaseDate) { return "Bought today" }
        if Calendar.current.isDateInYesterday(item.purchaseDate) { return "Bought yesterday" }
        let days = Calendar.current.dateComponents([.day], from: item.purchaseDate, to: .now).day ?? 0
        if days < 7 { return "Bought \(days)d ago" }
        return "Bought \(DateHelper.shortDate(item.purchaseDate))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: name + remove
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)

                    Text(item.category)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Remove button
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.textMuted)
                }
                .accessibilityLabel("Remove \(item.name)")
            }

            // Date info row — purchase + expiration
            HStack(spacing: 12) {
                // Purchase date
                HStack(spacing: 4) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 10))
                    Text(purchaseLabel)
                        .font(.caption)
                }
                .foregroundColor(.textSecondary)

                // Expiration date
                if let expLabel = expirationLabel {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(expLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(expirationColor)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("Long shelf life")
                            .font(.caption)
                    }
                    .foregroundColor(.textMuted)
                }
            }

            // Storage pills
            storagePills
        }
        .padding(16)
        .background(Color.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Storage Pills

    private var storagePills: some View {
        HStack(spacing: 8) {
            ForEach(StorageLocation.allCases) { location in
                Button {
                    onStorageChange(location)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: location.icon)
                            .font(.caption2)
                        Text(location.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        item.storage == location
                            ? Color.storageColor(location.rawValue).opacity(0.15)
                            : Color.surface2
                    )
                    .foregroundColor(
                        item.storage == location
                            ? Color.storageColor(location.rawValue)
                            : .textMuted
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                item.storage == location
                                    ? Color.storageColor(location.rawValue).opacity(0.4)
                                    : Color.border,
                                lineWidth: item.storage == location ? 1.5 : 0.5
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(location.displayName)\(item.storage == location ? ", selected" : "")")
            }
        }
    }

}
