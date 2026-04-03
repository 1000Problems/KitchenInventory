//
//  StorageDetailView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import SwiftData
import SwiftUI

struct StorageDetailView: View {
    let location: StorageLocation

    @Environment(\.modelContext) private var modelContext

    @Query private var allItems: [InventoryItem]

    @State private var searchText: String = ""
    @State private var collapsedCategories: Set<String> = []
    @State private var checkedItemIDs: Set<PersistentIdentifier> = []

    init(location: StorageLocation) {
        self.location = location

        let locationRaw = location.rawValue
        _allItems = Query(
            filter: #Predicate<InventoryItem> {
                !$0.isConsumed && $0.storageLocationRaw == locationRaw
            },
            sort: \InventoryItem.name
        )
    }

    // MARK: - Computed

    private var filteredItems: [InventoryItem] {
        guard !searchText.isEmpty else { return allItems }
        let query = searchText.lowercased()
        return allItems.filter {
            $0.name.lowercased().contains(query) ||
            $0.category.lowercased().contains(query)
        }
    }

    private var groupedByCategory: [(category: String, items: [InventoryItem])] {
        let grouped = Dictionary(grouping: filteredItems) { $0.category }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (category: $0.key, items: $0.value.sorted { a, b in
                let aDays = a.daysUntilExpiration ?? 999
                let bDays = b.daysUntilExpiration ?? 999
                if aDays != bDays { return aDays < bDays }
                return a.name < b.name
            }) }
    }

    private var urgentCount: Int {
        allItems.filter {
            $0.expirationUrgency == .danger || $0.expirationUrgency == .expired
        }.count
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBg
                .ignoresSafeArea()

            if allItems.isEmpty {
                emptyState
            } else {
                List {
                    // Summary strip
                    Section {
                        summaryStrip
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)

                    // Category groups
                    ForEach(groupedByCategory, id: \.category) { group in
                        Section {
                            if !collapsedCategories.contains(group.category) {
                                ForEach(group.items) { item in
                                    ItemDetailRow(
                                        item: item,
                                        isChecked: checkedItemIDs.contains(item.persistentModelID),
                                        onToggleCheck: { toggleChecked(item) }
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            toggleChecked(item)
                                        } label: {
                                            Label("Used", systemImage: "checkmark.circle")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        ForEach(StorageLocation.allCases.filter { $0 != item.storageLocation }) { loc in
                                            Button {
                                                moveItem(item, to: loc)
                                            } label: {
                                                Label(loc.displayName, systemImage: loc.icon)
                                            }
                                            .tint(Color.storageColor(loc.rawValue))
                                        }
                                    }
                                }
                            }
                        } header: {
                            categoryHeader(group.category, count: group.items.count)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search \(location.displayName.lowercased())...")
            }
        }
        .navigationTitle(location.displayName)
        .navigationBarTitleDisplayMode(.large)
        .onDisappear { consumeCheckedItems() }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: location.icon)
                .font(.system(size: 48))
                .foregroundColor(Color.storageColor(location.rawValue).opacity(0.4))

            Text("No items in \(location.displayName)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)

            Text("Ask the AI to add items here.")
                .font(.subheadline)
                .foregroundColor(.textSecondary)

            Spacer()
        }
    }

    // MARK: - Summary Strip

    private var summaryStrip: some View {
        HStack(spacing: 16) {
            Label("\(allItems.count) item\(allItems.count == 1 ? "" : "s")", systemImage: "tray.full.fill")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.textSecondary)

            if urgentCount > 0 {
                Label("\(urgentCount) need attention", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.error)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Category Header

    private func categoryHeader(_ category: String, count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                if collapsedCategories.contains(category) {
                    collapsedCategories.remove(category)
                } else {
                    collapsedCategories.insert(category)
                }
            }
        } label: {
            HStack {
                Text(category)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textSecondary)

                Text("(\(count))")
                    .font(.caption)
                    .foregroundColor(.textMuted)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .rotationEffect(.degrees(collapsedCategories.contains(category) ? 0 : 90))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Checkbox Toggle (workout app pattern)

    private func toggleChecked(_ item: InventoryItem) {
        let itemID = item.persistentModelID

        if checkedItemIDs.contains(itemID) {
            // Uncheck — undo
            HapticsHelper.tap()
            withAnimation(.easeInOut(duration: 0.2)) {
                checkedItemIDs.remove(itemID)
            }
        } else {
            // Check — stays checked until user navigates away
            HapticsHelper.success()
            withAnimation(.easeInOut(duration: 0.2)) {
                checkedItemIDs.insert(itemID)
            }
        }
    }

    // MARK: - Consume on Navigate Away

    private func consumeCheckedItems() {
        guard !checkedItemIDs.isEmpty else { return }
        for item in allItems where checkedItemIDs.contains(item.persistentModelID) {
            item.isConsumed = true
        }
        checkedItemIDs.removeAll()
        try? modelContext.save()
    }

    private func moveItem(_ item: InventoryItem, to newLocation: StorageLocation) {
        HapticsHelper.tap()
        withAnimation {
            item.storageLocation = newLocation
            try? modelContext.save()
        }
    }
}

// MARK: - Item Detail Row

struct ItemDetailRow: View {
    let item: InventoryItem
    var isChecked: Bool = false
    var onToggleCheck: (() -> Void)?

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
        HStack(spacing: 12) {
            // Checkbox
            if let onToggleCheck {
                Button(action: onToggleCheck) {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isChecked ? .success : .textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isChecked ? "Uncheck \(item.name)" : "Mark \(item.name) as used")
            } else {
                Circle()
                    .fill(urgencyColor)
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isChecked ? .textMuted : .textPrimary)
                    .strikethrough(isChecked)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(quantityLabel)

                    if let exp = item.effectiveExpiration {
                        Text("·")
                        Text(DateHelper.shortDate(exp))
                    }
                }
                .font(.caption)
                .foregroundColor(.textMuted)
            }

            Spacer()

            if !isChecked, let days = item.daysUntilExpiration {
                Text(expirationBadge(days))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(urgencyColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(urgencyColor.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Swipe right for move options, swipe left to mark as used, or tap checkbox")
    }

    private var accessibilityDescription: String {
        var parts = [item.name, quantityLabel]
        if let days = item.daysUntilExpiration {
            if days < 0 { parts.append("\(abs(days)) days overdue") }
            else if days == 0 { parts.append("expires today") }
            else if days == 1 { parts.append("expires tomorrow") }
            else { parts.append("expires in \(days) days") }
        }
        if isChecked { parts.append("checked off") }
        return parts.joined(separator: ", ")
    }

    private var quantityLabel: String {
        let qty = item.quantity
        let qtyStr = qty.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", qty) : String(format: "%.1f", qty)
        return "\(qtyStr) \(item.unit)"
    }

    private func expirationBadge(_ days: Int) -> String {
        if days < 0 { return "\(abs(days))d over" }
        if days == 0 { return "Today" }
        if days == 1 { return "1d" }
        return "\(days)d"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StorageDetailView(location: .fridge)
            .modelContainer(for: InventoryItem.self, inMemory: true)
    }
}
