//
//  ExpirationLearner.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/3/26.
//

import Foundation
import SwiftData

/// Learns from user expiration corrections to predict better expiration dates for future additions.
///
/// When a user corrects an AI-estimated expiration (via `update_expiration`), the correction
/// is stored on the InventoryItem as `userExpiration`. This service computes a running average
/// of corrections per canonical item name and returns learned durations.
struct ExpirationLearner {

    /// Returns the learned average expiration (in days from purchase) for a given item name,
    /// or nil if there's not enough data.
    ///
    /// Requires at least 2 user corrections to start overriding AI estimates.
    static func learnedExpirationDays(for itemName: String, context: ModelContext) -> Int? {
        let canonicalName = itemName.lowercased().trimmingCharacters(in: .whitespaces)

        // Find all consumed + active items with this name that have user corrections
        let descriptor = FetchDescriptor<InventoryItem>()
        guard let allItems = try? context.fetch(descriptor) else { return nil }

        let correctedItems = allItems.filter { item in
            item.name.lowercased().trimmingCharacters(in: .whitespaces) == canonicalName
            && item.userExpiration != nil
        }

        // Need at least 2 corrections to build confidence
        guard correctedItems.count >= 2 else { return nil }

        // Compute running average: days between purchaseDate and userExpiration
        let durations = correctedItems.compactMap { item -> Double? in
            guard let userExp = item.userExpiration else { return nil }
            let days = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: item.purchaseDate),
                to: Calendar.current.startOfDay(for: userExp)
            ).day
            guard let d = days, d > 0 else { return nil }
            return Double(d)
        }

        guard !durations.isEmpty else { return nil }

        let average = durations.reduce(0.0, +) / Double(durations.count)
        return max(1, Int(average.rounded()))
    }

    /// Returns the best expiration estimate for an item: learned > purchase history > fallback.
    /// This is used by AddItemsTool when the AI doesn't provide an explicit expiration.
    static func bestExpirationDays(
        for itemName: String,
        aiEstimate: Int?,
        context: ModelContext
    ) -> Int? {
        // Priority 1: User-learned expiration (from corrections)
        if let learned = learnedExpirationDays(for: itemName, context: context) {
            return learned
        }

        // Priority 2: Purchase history average
        let canonicalName = itemName.lowercased().trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<PurchaseHistory>(
            predicate: #Predicate { $0.canonicalName == canonicalName }
        )
        if let history = try? context.fetch(descriptor).first,
           history.purchaseCount >= 2,
           history.averageExpirationDays > 0 {
            return Int(history.averageExpirationDays.rounded())
        }

        // Priority 3: AI estimate (passed through)
        return aiEstimate
    }

    /// Returns top quick-add items ranked by frequency × recency, excluding dismissed items.
    static func quickAddItems(limit: Int = 8, context: ModelContext) -> [PurchaseHistory] {
        let descriptor = FetchDescriptor<PurchaseHistory>()
        guard let allHistory = try? context.fetch(descriptor) else { return [] }

        return allHistory
            .filter { !$0.isDismissed && $0.purchaseCount >= 2 }
            .sorted { $0.rankingScore > $1.rankingScore }
            .prefix(limit)
            .map { $0 }
    }
}
