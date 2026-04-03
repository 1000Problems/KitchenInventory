//
//  InventoryItem.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import Foundation
import SwiftData

@Model
final class InventoryItem {
    var name: String
    var category: String
    var storageLocationRaw: String
    var purchaseDate: Date
    var estimatedExpiration: Date?
    var userExpiration: Date?
    var quantity: Double
    var unit: String
    var isConsumed: Bool
    var source: String  // "manual", "voice", "receipt" (future)

    init(
        name: String,
        category: String = "Other",
        storageLocation: StorageLocation = .fridge,
        purchaseDate: Date = .now,
        estimatedExpiration: Date? = nil,
        userExpiration: Date? = nil,
        quantity: Double = 1,
        unit: String = "item",
        isConsumed: Bool = false,
        source: String = "manual"
    ) {
        self.name = name
        self.category = category
        self.storageLocationRaw = storageLocation.rawValue
        self.purchaseDate = purchaseDate
        self.estimatedExpiration = estimatedExpiration
        self.userExpiration = userExpiration
        self.quantity = quantity
        self.unit = unit
        self.isConsumed = isConsumed
        self.source = source
    }

    // MARK: - Computed Properties

    var storageLocation: StorageLocation {
        get { StorageLocation(rawValue: storageLocationRaw) ?? .fridge }
        set { storageLocationRaw = newValue.rawValue }
    }

    /// The effective expiration date (user override takes priority)
    var effectiveExpiration: Date? {
        userExpiration ?? estimatedExpiration
    }

    /// Days until expiration (negative = already expired)
    var daysUntilExpiration: Int? {
        guard let expDate = effectiveExpiration else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: expDate)).day
    }

    /// Whether the item is expired
    var isExpired: Bool {
        guard let days = daysUntilExpiration else { return false }
        return days < 0
    }

    /// Whether the item is expiring soon (within 3 days)
    var isExpiringSoon: Bool {
        guard let days = daysUntilExpiration else { return false }
        return days >= 0 && days <= 3
    }

    /// Expiration urgency level for color coding
    var expirationUrgency: ExpirationUrgency {
        guard let days = daysUntilExpiration else { return .none }
        if days < 0 { return .expired }
        if days <= 2 { return .danger }
        if days <= 5 { return .warning }
        return .safe
    }
}

enum ExpirationUrgency {
    case none
    case safe
    case warning
    case danger
    case expired
}
