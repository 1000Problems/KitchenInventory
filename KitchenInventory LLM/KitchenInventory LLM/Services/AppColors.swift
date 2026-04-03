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

    /// Creates an adaptive color that switches between light and dark values.
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }

    // MARK: - App Color Palette (adaptive light/dark)
    // See DESIGN.md for rationale. Warm palette evokes kitchen, food, home.

    static let appBg = Color(light: "FAF8F5", dark: "0A0A0A")
    static let surface1 = Color(light: "FFFFFF", dark: "1C1C1E")
    static let surface2 = Color(light: "F5F0EB", dark: "2C2824")
    static let surface3 = Color(light: "EBE5DE", dark: "3A3530")
    static let border = Color(light: "DDD5CC", dark: "3A3530")
    static let textPrimary = Color(light: "2C2C2E", dark: "FFFFFF")
    static let textSecondary = Color(light: "636366", dark: "ABABAF")
    static let textMuted = Color(light: "8E8E93", dark: "636366")
    static let accent = Color(light: "A7D3F0", dark: "7BBDE0")
    /// Text/icon color for use ON accent backgrounds — ensures contrast.
    static let accentContrast = Color(light: "1A3A50", dark: "0D2840")
    static let success = Color(light: "34C759", dark: "30D158")
    static let warning = Color(light: "E8A030", dark: "F0A830")
    static let error = Color(light: "FF3B30", dark: "FF453A")
    static let appPurple = Color(light: "7B8EC2", dark: "8B9ED2")
    static let gold = Color(light: "FFCC00", dark: "FFD60A")

    // MARK: - Storage Location Colors (dedicated, no longer aliased to semantic colors)

    static let pantryColor = Color(light: "D4A853", dark: "E0B860")
    static let fridgeColor = Color(light: "4A9B8E", dark: "5AABA0")
    static let freezerColor = Color(light: "7B8EC2", dark: "8B9ED2")

    static func storageColor(_ location: String) -> Color {
        switch location.lowercased() {
        case "pantry": return .pantryColor
        case "fridge": return .fridgeColor
        case "freezer": return .freezerColor
        default: return .textSecondary
        }
    }
}
