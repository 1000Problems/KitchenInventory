//
//  UserSettings.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import Foundation
import SwiftData

@Model
final class UserSettings {
    @Attribute(.unique) var id: String
    var onboardingComplete: Bool
    var preferredUnits: String  // "imperial" or "metric"

    init(
        id: String = "default",
        onboardingComplete: Bool = false,
        preferredUnits: String = "imperial"
    ) {
        self.id = id
        self.onboardingComplete = onboardingComplete
        self.preferredUnits = preferredUnits
    }
}
