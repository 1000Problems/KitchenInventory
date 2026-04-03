//
//  HapticsHelper.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/3/26.
//

import UIKit

/// Centralized haptic feedback for key interactions.
/// Uses pre-prepared generators for instant response.
enum HapticsHelper {

    // MARK: - Feedback Generators

    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let selectionFeedback = UISelectionFeedbackGenerator()
    private static let notificationFeedback = UINotificationFeedbackGenerator()

    // MARK: - Semantic Haptics

    /// Light tap — chip selection, toggle, minor interaction
    static func tap() {
        lightImpact.impactOccurred()
    }

    /// Medium tap — item added, action completed
    static func confirm() {
        mediumImpact.impactOccurred()
    }

    /// Heavy tap — delete, clear data, destructive action
    static func heavy() {
        heavyImpact.impactOccurred()
    }

    /// Selection changed — scrolling through items, picker change
    static func selection() {
        selectionFeedback.selectionChanged()
    }

    /// Success — item added successfully, recording started
    static func success() {
        notificationFeedback.notificationOccurred(.success)
    }

    /// Warning — item expiring, attention needed
    static func warning() {
        notificationFeedback.notificationOccurred(.warning)
    }

    /// Error — failed action, permission denied
    static func error() {
        notificationFeedback.notificationOccurred(.error)
    }

    /// Prepare generators for immediate response (call before expected interaction)
    static func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
}
