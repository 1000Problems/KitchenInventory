//
//  ParsedItem.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/3/26.
//

import Foundation

/// Represents an item parsed from a voice transcript, before being committed to inventory.
/// Used by the Voice Mode confirmation screen to let users review/edit before adding.
struct ParsedItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var category: String
    var storage: StorageLocation
    var quantity: Double
    var unit: String
    var expirationDays: Int?

    /// Purchase date — defaults to today
    var purchaseDate: Date = .now

    static func == (lhs: ParsedItem, rhs: ParsedItem) -> Bool {
        lhs.id == rhs.id
    }
}
