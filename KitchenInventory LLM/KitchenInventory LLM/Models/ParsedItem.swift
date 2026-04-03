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

    /// Absolute expiration date — computed by the AI from today's date + context.
    /// nil means no expiration (long-shelf pantry items, etc.)
    var expirationDate: Date?

    /// Purchase date — defaults to today, AI may adjust for "bought last week" etc.
    var purchaseDate: Date = .now

    static func == (lhs: ParsedItem, rhs: ParsedItem) -> Bool {
        lhs.id == rhs.id
    }
}
