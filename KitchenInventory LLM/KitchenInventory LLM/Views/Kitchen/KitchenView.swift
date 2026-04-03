//
//  KitchenView.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import SwiftData
import SwiftUI

struct KitchenView: View {
    /// Navigation path — reset from outside to pop to root on tab switch.
    @Binding var navigationPath: NavigationPath

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

    /// Names of items just added via Voice Mode — drives the "Just Added" section.
    /// Replaced each time a new Voice Mode batch is confirmed.
    @State private var justAddedNames: [String] = []

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

    /// Items matching the just-added names, in the order they were spoken.
    private var justAddedItems: [InventoryItem] {
        guard !justAddedNames.isEmpty else { return [] }
        let nameSet = Set(justAddedNames.map { $0.lowercased() })
        return allItems
            .filter { nameSet.contains($0.name.lowercased()) }
            .sorted { a, b in
                let idxA = justAddedNames.firstIndex(where: { $0.caseInsensitiveCompare(a.name) == .orderedSame }) ?? 999
                let idxB = justAddedNames.firstIndex(where: { $0.caseInsensitiveCompare(b.name) == .orderedSame }) ?? 999
                return idxA < idxB
            }
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
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.appBg
                    .ignoresSafeArea()

                if allItems.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            searchBar

                            if searchText.isEmpty {
                                if !justAddedItems.isEmpty {
                                    justAddedSection
                                }
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

            }
            .navigationTitle("Kitchen")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: StorageLocation.self) { location in
                StorageDetailView(location: location)
            }
            .onDisappear {
                consumeCheckedItems()
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToKitchenWithNewItems)) { notification in
                if let names = notification.object as? [String] {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        justAddedNames = names
                    }
                }
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
            if expandedItemID == item.persistentModelID {
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

            Text("Tap the mic to add your first\nitems by voice.")
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
                    UniversalItemRow(
                        item: item,
                        isChecked: checkedItemIDs.contains(item.persistentModelID),
                        isExpanded: expandedItemID == item.persistentModelID,
                        onToggleCheck: { toggleChecked(item) },
                        onToggleExpand: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedItemID = expandedItemID == item.persistentModelID ? nil : item.persistentModelID
                            }
                        },
                        onDateSelected: { updateExpiration(item, to: $0) },
                        onRecipe: { requestRecipe(for: item) },
                        onFreeze: { freezeItem(item) },
                        onRemove: { markExpired(item) }
                    )

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

    // MARK: - Just Added Section

    private var justAddedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.accent)
                    .font(.system(size: 15, weight: .semibold))

                Text("Just Added")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Text("\(justAddedItems.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.accentContrast)
                    .frame(width: 22, height: 22)
                    .background(Color.accent)
                    .clipShape(Circle())

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        justAddedNames = []
                    }
                } label: {
                    Text("Dismiss")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.textMuted)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(justAddedItems.enumerated()), id: \.element.persistentModelID) { index, item in
                    UniversalItemRow(
                        item: item,
                        isExpanded: expandedItemID == item.persistentModelID,
                        onToggleExpand: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedItemID = expandedItemID == item.persistentModelID ? nil : item.persistentModelID
                            }
                        },
                        onChangeStorage: { newStorage in
                            HapticsHelper.tap()
                            item.storageLocation = newStorage
                            try? modelContext.save()
                        },
                        onDateSelected: { updateExpiration(item, to: $0) },
                        onRemove: {
                            HapticsHelper.warning()
                            let name = item.name
                            withAnimation(.easeInOut(duration: 0.25)) {
                                item.isConsumed = true
                                justAddedNames.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
                                try? modelContext.save()
                            }
                        }
                    )

                    if index < justAddedItems.count - 1 {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
            .background(Color.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accent.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.accent.opacity(0.08), radius: 6, y: 3)
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
                    UniversalItemRow(
                        item: item,
                        isChecked: checkedItemIDs.contains(item.persistentModelID),
                        isExpanded: expandedItemID == item.persistentModelID,
                        onToggleCheck: { toggleChecked(item) },
                        onToggleExpand: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedItemID = expandedItemID == item.persistentModelID ? nil : item.persistentModelID
                            }
                        },
                        onDateSelected: { updateExpiration(item, to: $0) },
                        onRecipe: { requestRecipe(for: item) },
                        onFreeze: { freezeItem(item) },
                        onRemove: { markExpired(item) }
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
                        UniversalItemRow(
                            item: item,
                            isChecked: checkedItemIDs.contains(item.persistentModelID),
                            isExpanded: expandedItemID == item.persistentModelID,
                            onToggleCheck: { toggleChecked(item) },
                            onToggleExpand: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    expandedItemID = expandedItemID == item.persistentModelID ? nil : item.persistentModelID
                                }
                            },
                            onChangeStorage: { newStorage in
                                HapticsHelper.tap()
                                item.storageLocation = newStorage
                                try? modelContext.save()
                            },
                            onDateSelected: { updateExpiration(item, to: $0) },
                            onRecipe: { requestRecipe(for: item) },
                            onFreeze: { freezeItem(item) },
                            onRemove: { markExpired(item) }
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

}

// MARK: - Notification Names

extension Notification.Name {
    static let switchToAITab = Notification.Name("switchToAITab")
    static let switchToAITabWithPrompt = Notification.Name("switchToAITabWithPrompt")
    static let resetToOnboarding = Notification.Name("resetToOnboarding")
    static let switchToKitchenWithNewItems = Notification.Name("switchToKitchenWithNewItems")
    static let switchToRecordTab = Notification.Name("switchToRecordTab")
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


// MARK: - Preview

#Preview {
    KitchenView(navigationPath: .constant(NavigationPath()))
        .modelContainer(for: InventoryItem.self, inMemory: true)
}
