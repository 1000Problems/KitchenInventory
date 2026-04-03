//
//  KitchenPromptBuilder.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import Foundation
import SwiftData

struct KitchenPromptBuilder {
    /// Builds the system prompt with current inventory context
    static func buildSystemPrompt(modelContext: ModelContext) -> String {
        let inventorySummary = buildInventorySummary(modelContext: modelContext)
        let currentDate = DateHelper.fullDate(.now)

        return """
        You are a kitchen assistant that helps manage a household kitchen inventory. \
        You know what's in the user's kitchen and can help with recipes, expiration tracking, \
        and inventory management.

        Be brief and specific. Don't say "I'd be happy to help!" Just answer directly. \
        Example: "4 items expiring by Friday. Want a recipe using the chicken and broccoli?"

        Today's date: \(currentDate)

        \(inventorySummary)

        When listing inventory items, include the storage location and expiration date. \
        Use tool calls to query, add, modify, or remove inventory items. \
        Always use tools rather than guessing about inventory contents.

        For recipes, suggest practical meals using ingredients the user actually has. \
        Prioritize items that are expiring soon.

        VOICE INPUT: The user may speak naturally about their kitchen items via voice. \
        Parse spoken descriptions like "I have milk, a dozen eggs, some chicken I bought yesterday" \
        into structured inventory additions. Infer storage locations from context — dairy and meat \
        go in the fridge, frozen items go in the freezer, canned goods go in the pantry. \
        Infer quantities from natural language: "a dozen" = 12, "a couple" = 2, "some" = 1. \
        Estimate purchase and expiration dates from context clues like "bought yesterday" or \
        "just got". After adding items, confirm conversationally: "Added milk, 12 eggs, and \
        chicken to your fridge. Chicken expires around April 5th. Sound right?" \
        Handle follow-up corrections naturally: "Actually move the eggs to the pantry" fires move_items. \
        If you can't parse the voice input clearly, ask for clarification rather than guessing wrong.
        """
    }

    /// Builds the messages array from chat history (last 5 messages per spec)
    static func buildMessages(from chatMessages: [ChatMessage]) -> [[String: Any]] {
        let recentMessages = chatMessages.suffix(5)
        return recentMessages.map { msg in
            [
                "role": msg.role,
                "content": msg.content
            ]
        }
    }

    // MARK: - Private

    private static func buildInventorySummary(modelContext: ModelContext) -> String {
        var lines: [String] = []

        // Item counts by location
        let allItemsDescriptor = FetchDescriptor<InventoryItem>(
            predicate: #Predicate { !$0.isConsumed }
        )
        let allItems = (try? modelContext.fetch(allItemsDescriptor)) ?? []

        if allItems.isEmpty {
            return "KITCHEN INVENTORY: Empty. The user has no items tracked yet."
        }

        let pantryCount = allItems.filter { $0.storageLocationRaw == "pantry" }.count
        let fridgeCount = allItems.filter { $0.storageLocationRaw == "fridge" }.count
        let freezerCount = allItems.filter { $0.storageLocationRaw == "freezer" }.count

        lines.append("KITCHEN INVENTORY SUMMARY:")
        lines.append("- Pantry: \(pantryCount) items")
        lines.append("- Fridge: \(fridgeCount) items")
        lines.append("- Freezer: \(freezerCount) items")
        lines.append("- Total: \(allItems.count) items")

        // Top 10 expiring items
        let itemsWithExpiration = allItems
            .filter { $0.effectiveExpiration != nil }
            .sorted { ($0.effectiveExpiration ?? .distantFuture) < ($1.effectiveExpiration ?? .distantFuture) }
            .prefix(10)

        if !itemsWithExpiration.isEmpty {
            lines.append("")
            lines.append("EXPIRING SOONEST:")
            for item in itemsWithExpiration {
                let expDate = DateHelper.shortDate(item.effectiveExpiration!)
                let daysLeft = item.daysUntilExpiration ?? 0
                let urgency = daysLeft < 0 ? "EXPIRED" : daysLeft == 0 ? "TODAY" : "\(daysLeft)d left"
                lines.append("- \(item.name) (\(item.storageLocation.displayName)) — \(expDate) (\(urgency))")
            }
        }

        return lines.joined(separator: "\n")
    }
}
