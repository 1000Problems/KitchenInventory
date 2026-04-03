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
                                onQuantityChange: { qty in
                                    viewModel.updateParsedItemQuantity(item, to: qty)
                                },
                                onDateChange: { date in
                                    viewModel.updateParsedItemDate(item, to: date)
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
            .foregroundColor(.white)
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
    let onQuantityChange: (Double) -> Void
    let onDateChange: (Date) -> Void
    let onRemove: () -> Void

    @State private var showDatePicker = false

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

                // Quantity stepper
                quantityStepper

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

            // Storage pills
            storagePills

            // Purchase date buttons
            purchaseDateButtons
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

    // MARK: - Quantity Stepper

    private var quantityStepper: some View {
        HStack(spacing: 4) {
            Button {
                let newQty = max(1, item.quantity - 1)
                onQuantityChange(newQty)
            } label: {
                Image(systemName: "minus")
                    .font(.caption.bold())
                    .foregroundColor(.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Color.surface2)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text("\(Int(item.quantity))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
                .frame(minWidth: 24)

            Button {
                onQuantityChange(item.quantity + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.caption.bold())
                    .foregroundColor(.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Color.surface2)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quantity \(Int(item.quantity))")
    }

    // MARK: - Purchase Date Buttons

    private var purchaseDateButtons: some View {
        HStack(spacing: 8) {
            Text("Bought:")
                .font(.caption)
                .foregroundColor(.textMuted)

            // Today
            datePill("Today", date: Date.now, isSelected: Calendar.current.isDateInToday(item.purchaseDate))

            // Yesterday
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
            datePill("Yesterday", date: yesterday, isSelected: Calendar.current.isDateInYesterday(item.purchaseDate))

            // This week (3 days ago as a rough "earlier this week")
            let earlier = Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now
            let isEarlier = !Calendar.current.isDateInToday(item.purchaseDate)
                && !Calendar.current.isDateInYesterday(item.purchaseDate)
                && item.purchaseDate < Date.now
            datePill("Earlier", date: earlier, isSelected: isEarlier)
        }
    }

    private func datePill(_ label: String, date: Date, isSelected: Bool) -> some View {
        Button {
            onDateChange(date)
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accent.opacity(0.12) : Color.surface2)
                .foregroundColor(isSelected ? .accent : .textSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
