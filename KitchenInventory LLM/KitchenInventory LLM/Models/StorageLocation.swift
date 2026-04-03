//
//  StorageLocation.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import Foundation

enum StorageLocation: String, Codable, CaseIterable, Identifiable, Hashable {
    case pantry
    case fridge
    case freezer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pantry: return "Pantry"
        case .fridge: return "Fridge"
        case .freezer: return "Freezer"
        }
    }

    var icon: String {
        switch self {
        case .pantry: return "cabinet.fill"
        case .fridge: return "refrigerator.fill"
        case .freezer: return "snowflake"
        }
    }
}
