//
//  AppColors.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // App color palette
    static let appBg = Color(hex: "f5f5f7")
    static let surface1 = Color(hex: "ffffff")
    static let surface2 = Color(hex: "f0f0f3")
    static let surface3 = Color(hex: "e5e5ea")
    static let border = Color(hex: "d1d1d6")
    static let textPrimary = Color(hex: "1c1c1e")
    static let textSecondary = Color(hex: "636366")
    static let textMuted = Color(hex: "8e8e93")
    static let accent = Color(hex: "4a6cf7")
    static let success = Color(hex: "34c759")
    static let warning = Color(hex: "ff9500")
    static let error = Color(hex: "ff3b30")
    static let appPurple = Color(hex: "af52de")
    static let gold = Color(hex: "ffcc00")

    // Storage location colors
    static func storageColor(_ location: String) -> Color {
        switch location.lowercased() {
        case "pantry": return .warning
        case "fridge": return .accent
        case "freezer": return .appPurple
        default: return .textSecondary
        }
    }
}
