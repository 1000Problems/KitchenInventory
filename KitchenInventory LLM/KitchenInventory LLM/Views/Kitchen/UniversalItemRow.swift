//
//  UniversalItemRow.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/3/26.
//

import SwiftData
import SwiftUI

/// A single, consistent item row used everywhere: Expiring Soon, Recently Added,
/// Just Added, Search Results, and StorageDetailView.
///
/// Collapsed: storage icon + name + subtitle + expiration badge + chevron
/// Expanded: storage pills, expiration adjuster, action buttons
struct UniversalItemRow: View {
    let item: InventoryItem

    // State
    var isChecked: Bool = false
    var isExpanded: Bool = false

    // Required handlers
    var onToggleCheck: (() -> Void)? = nil
    var onToggleExpand: (() -> Void)? = nil

    // Action handlers (show when provided)
    var onChangeStorage: ((StorageLocation) -> Void)? = nil
    var onDateSelected: ((Date) -> Void)? = nil
    var onRecipe: (() -> Void)? = nil
    var onFreeze: (() -> Void)? = nil
    var onRemove: (() -> Void)? = nil

    private var urgencyColor: Color {
        switch item.expirationUrgency {
        case .expired: return .error
        case .danger: return .error
        case .warning: return .warning
        case .safe: return .success
        case .none: return .textMuted
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            mainRow

            // Expandable action panel
            if isExpanded {
                actionPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Main Row

    private var mainRow: some View {
        HStack(spacing: 10) {
            // Checkbox
            if let onToggleCheck {
                Button(action: onToggleCheck) {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isChecked ? .success : .textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isChecked ? "Uncheck \(item.name)" : "Mark \(item.name) as used")
            }

            // Tappable content area → expand/collapse
            Button {
                onToggleExpand?()
            } label: {
                HStack(spacing: 8) {
                    // Storage icon with urgency ring
                    storageIcon

                    // Name + subtitle
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isChecked ? .textMuted : .textPrimary)
                            .strikethrough(isChecked)
                            .lineLimit(1)

                        Text(subtitleText)
                            .font(.caption)
                            .foregroundColor(.textMuted)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Expiration badge
                    if !isChecked, let days = item.daysUntilExpiration {
                        expirationBadge(days)
                    }

                    // Expand chevron
                    if onToggleExpand != nil && !isChecked {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.textMuted)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isChecked)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Storage Icon

    private var storageIcon: some View {
        Image(systemName: item.storageLocation.icon)
            .font(.system(size: 13))
            .foregroundColor(Color.storageColor(item.storageLocationRaw))
            .frame(width: 28, height: 28)
            .background(Color.storageColor(item.storageLocationRaw).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        item.daysUntilExpiration != nil ? urgencyColor.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
    }

    // MARK: - Subtitle

    private var subtitleText: String {
        var parts: [String] = []
        let qty = item.quantity
        let qtyStr = qty.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", qty) : String(format: "%.1f", qty)
        parts.append("\(qtyStr) \(item.unit)")
        parts.append(item.storageLocation.displayName)
        if let exp = item.effectiveExpiration {
            parts.append(DateHelper.shortDate(exp))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Expiration Badge

    private func expirationBadge(_ days: Int) -> some View {
        Text(badgeText(days))
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(urgencyColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(urgencyColor.opacity(0.1))
            .clipShape(Capsule())
    }

    private func badgeText(_ days: Int) -> String {
        if days < 0 { return "\(abs(days))d over" }
        if days == 0 { return "Today" }
        if days == 1 { return "1d" }
        return "\(days)d"
    }

    // MARK: - Expanded Action Panel

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Context line
            contextLine

            // Storage pills
            if onChangeStorage != nil {
                storagePills
            }

            // Expiration date adjuster
            if onDateSelected != nil, item.effectiveExpiration != nil {
                expirationAdjuster
            }

            // Action buttons
            actionButtons
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .padding(.top, 4)
    }

    // MARK: - Context Line

    private var contextLine: some View {
        HStack(spacing: 6) {
            Text(item.category)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.surface2)
                .clipShape(Capsule())

            Text("Added \(DateHelper.relativeDescription(item.purchaseDate))")
                .font(.caption)
                .foregroundColor(.textMuted)

            Spacer()
        }
    }

    // MARK: - Storage Pills

    private var storagePills: some View {
        HStack(spacing: 6) {
            Text("Move:")
                .font(.caption)
                .foregroundColor(.textMuted)

            ForEach(StorageLocation.allCases) { location in
                Button {
                    onChangeStorage?(location)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: location.icon)
                            .font(.system(size: 9))
                        Text(location.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        item.storageLocation == location
                            ? Color.storageColor(location.rawValue).opacity(0.15)
                            : Color.surface2
                    )
                    .foregroundColor(
                        item.storageLocation == location
                            ? Color.storageColor(location.rawValue)
                            : .textMuted
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                item.storageLocation == location
                                    ? Color.storageColor(location.rawValue).opacity(0.4)
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Expiration Adjuster

    private var expirationAdjuster: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Mark expired button
                Button {
                    onToggleCheck?()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Used")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundColor(.white)
                    .background(Color.error)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Current expiration
                if let exp = item.effectiveExpiration {
                    Text(DateHelper.shortDate(exp))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accent.opacity(0.12))
                        .clipShape(Capsule())

                    // Quick-adjust buttons
                    ForEach(adjustmentDays, id: \.self) { days in
                        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: exp) {
                            Button {
                                onDateSelected?(newDate)
                            } label: {
                                Text("+\(days)d")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.surface2)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var adjustmentDays: [Int] {
        let daysLeft = item.daysUntilExpiration ?? 0
        if daysLeft <= 3 { return [1, 2, 3, 5] }
        return [3, 5, 7, 14]
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if let onRecipe {
                Button(action: onRecipe) {
                    HStack(spacing: 4) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 11))
                        Text("Recipe")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accent.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if let onFreeze, item.storageLocation != .freezer {
                Button(action: onFreeze) {
                    HStack(spacing: 4) {
                        Image(systemName: "snowflake")
                            .font(.system(size: 11))
                        Text("Freeze")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.freezerColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.freezerColor.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if let onRemove {
                Button(action: onRemove) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Remove")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.error)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.error.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }
}
