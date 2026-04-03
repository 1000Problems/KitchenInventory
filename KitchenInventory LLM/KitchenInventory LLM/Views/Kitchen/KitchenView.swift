//
//  KitchenView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import SwiftData
import SwiftUI

struct KitchenView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(
        filter: #Predicate<InventoryItem> { !$0.isConsumed },
        sort: \InventoryItem.name
    )
    private var allItems: [InventoryItem]

    @State private var searchText: String = ""
    @State private var expandedItemID: PersistentIdentifier?
    @State private var checkedItemIDs: Set<PersistentIdentifier> = []
    @State private var actionToast: ActionToastData?

    struct ActionToastData: Identifiable {
        let id = UUID()
        let message: String
        let undoAction: () -> Void
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

    private var expiringSoonItems: [InventoryItem] {
        allItems
            .filter {
                guard let days = $0.daysUntilExpiration else { return false }
                return !$0.isExpired && days >= 0 && days <= 7
            }
            .sorted { ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999) }
    }

    private var expiredItems: [InventoryItem] {
        allItems.filter { $0.isExpired }
    }

    private var combinedExpiringItems: [InventoryItem] {
        (expiredItems + expiringSoonItems)
            .sorted { ($0.daysUntilExpiration ?? -999) < ($1.daysUntilExpiration ?? -999) }
            .prefix(5)
            .map { $0 }
    }

    private var recentlyAddedItems: [InventoryItem] {
        allItems
            .sorted { $0.purchaseDate > $1.purchaseDate }
            .prefix(5)
            .map { $0 }
    }

    private func itemCount(for location: StorageLocation) -> Int {
        allItems.filter { $0.storageLocation == location }.count
    }

    private func urgentCount(for location: StorageLocation) -> Int {
        allItems.filter {
            $0.storageLocation == location &&
            ($0.expirationUrgency == .danger || $0.expirationUrgency == .expired)
        }.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.appBg
                    .ignoresSafeArea()

                if allItems.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            searchBar

                            if searchText.isEmpty {
                                if !combinedExpiringItems.isEmpty {
                                    expiringSoonSection
                                }
                                storageCardsSection
                                if !recentlyAddedItems.isEmpty {
                                    recentlyAddedSection
                                }
                            } else {
                                searchResultsSection
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 80)
                    }
                    .onTapGesture {
                        // Tap anywhere outside collapses expanded row
                        if expandedItemID != nil {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedItemID = nil
                            }
                        }
                    }
                }

                addButton
            }
            .navigationTitle("Kitchen")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: StorageLocation.self) { location in
                StorageDetailView(location: location)
            }
            .onDisappear {
                consumeCheckedItems()
            }
            .overlay(alignment: .bottom) {
                if let toast = actionToast {
                    actionToastView(toast)
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Checkbox Toggle (workout app pattern)
    // Checked items stay visible with strikethrough. Navigate away → they're consumed.

    private func toggleChecked(_ item: InventoryItem) {
        let itemID = item.persistentModelID

        if checkedItemIDs.contains(itemID) {
            // Uncheck — undo
            HapticsHelper.tap()
            withAnimation(.easeInOut(duration: 0.2)) {
                checkedItemIDs.remove(itemID)
            }
        } else {
            // Check
            HapticsHelper.success()
            withAnimation(.easeInOut(duration: 0.2)) {
                checkedItemIDs.insert(itemID)
            }

            // Collapse if this item was expanded
            if expandedItemID == item.id {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedItemID = nil
                }
            }
        }
    }

    /// Consume all checked items when user navigates away from this view.
    private func consumeCheckedItems() {
        guard !checkedItemIDs.isEmpty else { return }
        for item in allItems where checkedItemIDs.contains(item.persistentModelID) {
            item.isConsumed = true
        }
        checkedItemIDs.removeAll()
        try? modelContext.save()
    }

    private func updateExpiration(_ item: InventoryItem, to newDate: Date) {
        HapticsHelper.confirm()
        item.userExpiration = newDate
        try? modelContext.save()

        withAnimation(.easeInOut(duration: 0.25)) {
            expandedItemID = nil
        }

        showActionToast("\(item.name) → \(DateHelper.shortDate(newDate))") {
            item.userExpiration = nil
            try? modelContext.save()
        }
    }

    private func markExpired(_ item: InventoryItem) {
        toggleChecked(item)
    }

    private func freezeItem(_ item: InventoryItem) {
        HapticsHelper.confirm()
        let previousLocation = item.storageLocation
        let previousExpiration = item.userExpiration
        item.storageLocation = .freezer
        item.userExpiration = DateHelper.daysFromNow(30)
        try? modelContext.save()

        withAnimation(.easeInOut(duration: 0.25)) {
            expandedItemID = nil
        }

        showActionToast("\(item.name) → Freezer") {
            item.storageLocation = previousLocation
            item.userExpiration = previousExpiration
            try? modelContext.save()
        }
    }

    private func showActionToast(_ message: String, undo: @escaping () -> Void) {
        withAnimation(.easeInOut(duration: 0.25)) {
            actionToast = ActionToastData(message: message, undoAction: undo)
        }
        let toastID = actionToast?.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation {
                if actionToast?.id == toastID {
                    actionToast = nil
                }
            }
        }
    }

    private func requestRecipe(for item: InventoryItem) {
        expandedItemID = nil
        let days = item.daysUntilExpiration ?? 0
        let prompt = "Suggest a quick recipe using \(item.name) that's expiring in \(max(0, days)) days."
        NotificationCenter.default.post(name: .switchToAITabWithPrompt, object: prompt)
    }

    // MARK: - Action Toast (for date changes, freeze — NOT for used checkbox)

    private func actionToastView(_ toast: ActionToastData) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.success)
                .font(.system(size: 16))

            Text(toast.message)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()

            Button("Undo") {
                toast.undoAction()
                withAnimation {
                    actionToast = nil
                }
            }
            .font(.subheadline.bold())
            .foregroundColor(.success)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.textPrimary)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "refrigerator.fill")
                .font(.system(size: 56))
                .foregroundColor(.accent.opacity(0.5))

            Text("Your kitchen is empty")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)

            Text("Talk to the AI assistant to add\nyour first items via voice or text.")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textMuted)
                .font(.system(size: 15))

            TextField("Search items...", text: $searchText)
                .font(.body)
                .foregroundColor(.textPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textMuted)
                        .font(.system(size: 15))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Expiring Soon Section

    private var expiringSoonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundColor(.warning)
                    .font(.system(size: 15, weight: .semibold))

                Text("Expiring Soon")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                if expiredItems.count > 0 {
                    Text("\(expiredItems.count) expired")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.error)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.error.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(combinedExpiringItems.enumerated()), id: \.element.persistentModelID) { index, item in
                    VStack(spacing: 0) {
                        // Main row
                        ExpiringItemRow(
                            item: item,
                            isExpanded: expandedItemID == item.id,
                            isChecked: checkedItemIDs.contains(item.persistentModelID),
                            onToggleCheck: { toggleChecked(item) },
                            onToggleExpand: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    expandedItemID = expandedItemID == item.id ? nil : item.id
                                }
                            }
                        )

                        // Expandable panel
                        if expandedItemID == item.id {
                            ExpandedItemPanel(
                                item: item,
                                onExpired: { markExpired(item) },
                                onDateSelected: { updateExpiration(item, to: $0) },
                                onRecipe: { requestRecipe(for: item) },
                                onFreeze: { freezeItem(item) }
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    if index < combinedExpiringItems.count - 1 {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
            .background(Color.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
    }

    // MARK: - Storage Cards

    private var storageCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage")
                .font(.headline)
                .foregroundColor(.textPrimary)

            VStack(spacing: 10) {
                ForEach(StorageLocation.allCases) { location in
                    NavigationLink(value: location) {
                        StorageCardContent(
                            location: location,
                            itemCount: itemCount(for: location),
                            urgentCount: urgentCount(for: location)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Recently Added

    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.success)
                    .font(.system(size: 15, weight: .semibold))

                Text("Recently Added")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
            }

            VStack(spacing: 0) {
                ForEach(Array(recentlyAddedItems.enumerated()), id: \.element.persistentModelID) { index, item in
                    RecentItemRow(
                            item: item,
                            isChecked: checkedItemIDs.contains(item.persistentModelID),
                            onToggleCheck: { toggleChecked(item) }
                        )

                    if index < recentlyAddedItems.count - 1 {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
            .background(Color.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(filteredItems.count) result\(filteredItems.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundColor(.textSecondary)

            if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.textMuted)
                    Text("No items match \"\(searchText)\"")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.persistentModelID) { index, item in
                        SearchResultRow(
                                item: item,
                                isChecked: checkedItemIDs.contains(item.persistentModelID),
                                onToggleCheck: { toggleChecked(item) }
                            )

                        if index < filteredItems.count - 1 {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
                .background(Color.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            }
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            NotificationCenter.default.post(name: .switchToAITab, object: nil)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.accent)
                .clipShape(Circle())
                .shadow(color: .accent.opacity(0.35), radius: 8, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 16)
        .accessibilityLabel("Add items via AI")
        .accessibilityHint("Opens the AI tab to add items by voice or text")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let switchToAITab = Notification.Name("switchToAITab")
    static let switchToAITabWithPrompt = Notification.Name("switchToAITabWithPrompt")
}

// MARK: - Expiring Item Row (with Used button + caret)

struct ExpiringItemRow: View {
    let item: InventoryItem
    let isExpanded: Bool
    let isChecked: Bool
    let onToggleCheck: () -> Void
    let onToggleExpand: () -> Void

    private var urgencyColor: Color {
        switch item.expirationUrgency {
        case .expired: return .error
        case .danger: return .error
        case .warning: return .warning
        case .safe: return .success
        case .none: return .textMuted
        }
    }

    private var expirationLabel: String {
        guard let days = item.daysUntilExpiration else { return "" }
        if days < 0 { return "\(abs(days))d overdue" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "\(days)d left"
    }

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button(action: onToggleCheck) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isChecked ? .success : .textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isChecked ? "Uncheck \(item.name)" : "Mark \(item.name) as used")

            // Item info (tappable to expand)
            Button(action: onToggleExpand) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(urgencyColor)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isChecked ? .textMuted : .textPrimary)
                            .strikethrough(isChecked)
                            .lineLimit(1)

                        Text(item.storageLocation.displayName)
                            .font(.caption)
                            .foregroundColor(.textMuted)
                    }

                    Spacer()

                    if !isChecked {
                        Text(expirationLabel)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(urgencyColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(urgencyColor.opacity(0.1))
                            .clipShape(Capsule())

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.storageLocation.displayName), \(expirationLabel)\(isChecked ? ", checked off" : "")")
    }
}

// MARK: - Expanded Item Panel

struct ExpandedItemPanel: View {
    let item: InventoryItem
    let onExpired: () -> Void
    let onDateSelected: (Date) -> Void
    let onRecipe: () -> Void
    let onFreeze: () -> Void

    private var daysSincePurchase: Int {
        Calendar.current.dateComponents([.day], from: item.purchaseDate, to: .now).day ?? 0
    }

    private var contextLine: String {
        let bought = "Bought \(DateHelper.shortDate(item.purchaseDate))"
        let duration = "In your \(item.storageLocation.displayName.lowercased()) \(daysSincePurchase) day\(daysSincePurchase == 1 ? "" : "s")"
        return "\(bought) · \(duration)"
    }

    /// Generate date options for the strip
    private var dateOptions: [DateOption] {
        guard let currentExp = item.effectiveExpiration else { return [] }
        let daysLeft = item.daysUntilExpiration ?? 0

        // Context-aware intervals
        let intervals: [Int]
        if daysLeft <= 3 {
            intervals = [1, 2, 3, 5]
        } else {
            intervals = [3, 5, 7, 14]
        }

        var options: [DateOption] = []

        // Current expiration (selected)
        options.append(DateOption(
            date: currentExp,
            isCurrent: true
        ))

        // Future dates
        for days in intervals {
            if let futureDate = Calendar.current.date(byAdding: .day, value: days, to: currentExp) {
                options.append(DateOption(
                    date: futureDate,
                    isCurrent: false
                ))
            }
        }

        return options
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Context line
            Text(contextLine)
                .font(.caption)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 14)

            // Date strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // Expired button
                    Button(action: onExpired) {
                        VStack(spacing: 3) {
                            Text("EXPIRED")
                                .font(.system(size: 9, weight: .bold))
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(width: 52, height: 52)
                        .foregroundColor(.white)
                        .background(Color.error)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mark as expired")

                    // Date options
                    ForEach(dateOptions) { option in
                        if option.isCurrent {
                            // Current date — visually distinct, non-interactive
                            VStack(spacing: 3) {
                                Text(DateHelper.dayOfWeek(option.date))
                                    .font(.system(size: 9, weight: .bold))
                                Text("\(DateHelper.dayNumber(option.date))")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .frame(width: 52, height: 52)
                            .foregroundColor(.white)
                            .background(Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityLabel("Current expiration \(DateHelper.shortDate(option.date))")
                        } else {
                            // Future date — tappable
                            Button {
                                onDateSelected(option.date)
                            } label: {
                                VStack(spacing: 3) {
                                    Text(DateHelper.dayOfWeek(option.date))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.textMuted)
                                    Text("\(DateHelper.dayNumber(option.date))")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.textPrimary)
                                }
                                .frame(width: 52, height: 52)
                                .background(Color.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Extend to \(DateHelper.shortDate(option.date))")
                        }
                    }
                }
                .padding(.horizontal, 14)
            }

            // Action buttons
            HStack(spacing: 10) {
                Button(action: onRecipe) {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 12))
                        Text("Recipe")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accent.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if item.storageLocation != .freezer {
                    Button(action: onFreeze) {
                        HStack(spacing: 6) {
                            Image(systemName: "snowflake")
                                .font(.system(size: 12))
                            Text("Freeze it")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.appPurple)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.appPurple.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 12)
    }
}

// MARK: - Date Option

struct DateOption: Identifiable {
    let id = UUID()
    let date: Date
    let isCurrent: Bool
}

// MARK: - Storage Card

struct StorageCardContent: View {
    let location: StorageLocation
    let itemCount: Int
    let urgentCount: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: location.icon)
                .font(.system(size: 22))
                .foregroundColor(Color.storageColor(location.rawValue))
                .frame(width: 40, height: 40)
                .background(Color.storageColor(location.rawValue).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(location.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)

                Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            if urgentCount > 0 {
                Text("\(urgentCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.error)
                    .clipShape(Circle())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textMuted)
        }
        .padding(14)
        .background(Color.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(location.displayName), \(itemCount) items\(urgentCount > 0 ? ", \(urgentCount) need attention" : "")")
        .accessibilityHint("Tap to view items")
    }
}

// MARK: - Recent Item Row (with Used button)

struct RecentItemRow: View {
    let item: InventoryItem
    let isChecked: Bool
    let onToggleCheck: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button(action: onToggleCheck) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isChecked ? .success : .textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isChecked ? "Uncheck \(item.name)" : "Mark \(item.name) as used")

            Image(systemName: item.storageLocation.icon)
                .font(.system(size: 14))
                .foregroundColor(Color.storageColor(item.storageLocationRaw))
                .frame(width: 28, height: 28)
                .background(Color.storageColor(item.storageLocationRaw).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .foregroundColor(isChecked ? .textMuted : .textPrimary)
                    .strikethrough(isChecked)
                    .lineLimit(1)

                Text(item.storageLocation.displayName)
                    .font(.caption)
                    .foregroundColor(.textMuted)
            }

            Spacer()

            Text(DateHelper.relativeDescription(item.purchaseDate))
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Search Result Row (with Used button)

struct SearchResultRow: View {
    let item: InventoryItem
    let isChecked: Bool
    let onToggleCheck: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button(action: onToggleCheck) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isChecked ? .success : .textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isChecked ? "Uncheck \(item.name)" : "Mark \(item.name) as used")

            Image(systemName: item.storageLocation.icon)
                .font(.system(size: 14))
                .foregroundColor(Color.storageColor(item.storageLocationRaw))
                .frame(width: 28, height: 28)
                .background(Color.storageColor(item.storageLocationRaw).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .foregroundColor(isChecked ? .textMuted : .textPrimary)
                    .strikethrough(isChecked)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(item.storageLocation.displayName)
                    if let exp = item.effectiveExpiration {
                        Text("·")
                        Text(DateHelper.shortDate(exp))
                    }
                }
                .font(.caption)
                .foregroundColor(.textMuted)
            }

            Spacer()

            if item.expirationUrgency == .danger || item.expirationUrgency == .expired {
                Circle()
                    .fill(Color.error)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

#Preview {
    KitchenView()
        .modelContainer(for: InventoryItem.self, inMemory: true)
}
