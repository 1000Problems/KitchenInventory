//
//  PurchaseHistory.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import Foundation
import SwiftData

@Model
final class PurchaseHistory {
    @Attribute(.unique) var canonicalName: String
    var purchaseCount: Int
    var lastPurchaseDate: Date
    var preferredStorageRaw: String
    var averageExpirationDays: Double
    var category: String
    var dismissCount: Int

    init(
        canonicalName: String,
        purchaseCount: Int = 1,
        lastPurchaseDate: Date = .now,
        preferredStorage: StorageLocation = .fridge,
        averageExpirationDays: Double = 7,
        category: String = "Other",
        dismissCount: Int = 0
    ) {
        self.canonicalName = canonicalName
        self.purchaseCount = purchaseCount
        self.lastPurchaseDate = lastPurchaseDate
        self.preferredStorageRaw = preferredStorage.rawValue
        self.averageExpirationDays = averageExpirationDays
        self.category = category
        self.dismissCount = dismissCount
    }

    // MARK: - Computed Properties

    var preferredStorage: StorageLocation {
        get { StorageLocation(rawValue: preferredStorageRaw) ?? .fridge }
        set { preferredStorageRaw = newValue.rawValue }
    }

    /// Whether this item has been dismissed too many times (auto-suppress threshold)
    var isDismissed: Bool {
        dismissCount >= 3
    }

    /// Quick-add ranking score: frequency weighted by recency
    var rankingScore: Double {
        let daysSinceLastPurchase = max(1, Calendar.current.dateComponents([.day], from: lastPurchaseDate, to: .now).day ?? 1)
        let recencyWeight = 1.0 / (1.0 + Double(daysSinceLastPurchase) / 30.0)
        return Double(purchaseCount) * recencyWeight
    }
}
