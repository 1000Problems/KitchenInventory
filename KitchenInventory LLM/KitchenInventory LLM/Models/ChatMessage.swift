//
//  ChatMessage.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import Foundation
import SwiftData

@Model
final class ChatMessage {
    @Attribute(.unique) var id: String
    var role: String  // "user", "assistant"
    var content: String
    var timestamp: Date
    /// Optional structured data for rich AI responses (inventory items as JSON)
    var structuredData: String?

    init(
        id: String = UUID().uuidString,
        role: String,
        content: String,
        timestamp: Date = .now,
        structuredData: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.structuredData = structuredData
    }

    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }
}
