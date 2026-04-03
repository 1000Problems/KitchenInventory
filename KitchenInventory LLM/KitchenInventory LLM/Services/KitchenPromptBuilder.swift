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
        let purchaseContext = buildPurchaseHistoryContext(modelContext: modelContext)
        let currentDate = DateHelper.fullDate(.now)

        return """
        You are a kitchen assistant that helps manage a household kitchen inventory. \
        You know what's in the user's kitchen and can help with recipes, expiration tracking, \
        and inventory management.

        Be brief and specific. Don't say "I'd be happy to help!" Just answer directly. \
        Example: "4 items expiring by Friday. Want a recipe using the chicken and broccoli?"

        EXPIRING ITEMS FORMAT — when listing what's expiring, format each item on its own line like: \
        "🔴 Chicken (Fridge) — EXPIRED 2 days ago" or "🟡 Milk (Fridge) — 3 days left" or \
        "🟢 Rice (Pantry) — 12 days left". Group them: expired first, then urgent (0-3 days), \
        then soon (4-7 days). Use emoji dots for urgency: 🔴 expired, 🟡 1-3 days, 🟢 4+ days. \
        Keep it scannable — no paragraphs, just the list.

        Today's date: \(currentDate)

        \(inventorySummary)

        \(purchaseContext)

        When listing inventory items, include the storage location and expiration date. \
        Use tool calls to query, add, modify, or remove inventory items. \
        Always use tools rather than guessing about inventory contents.

        For recipes, suggest practical meals using ingredients the user actually has. \
        Prioritize items that are expiring soon.

        STORAGE LOCATION RULES — follow these strictly:
        FRIDGE: milk, eggs, butter, cheese, yogurt, cream, sour cream, cream cheese, \
        fresh meat (chicken, beef, pork, fish, ground meat, steaks, sausage), deli meats, \
        fresh fruits and vegetables (lettuce, spinach, berries, grapes, carrots, celery, peppers, \
        broccoli, herbs, tomatoes, avocados, lemons, limes, oranges, apples), hummus, \
        salsa, fresh juice, tofu, tortillas (flour/corn), opened condiments, leftovers.
        PANTRY: canned goods, dried pasta, rice, beans (dried), flour, sugar, salt, pepper, \
        spices, cooking oil, vinegar, cereal, oats, granola, crackers, chips, cookies, \
        bread, peanut butter, jelly/jam (unopened), honey, coffee, tea, baking soda, \
        baking powder, chocolate, nuts, dried fruit, soy sauce, hot sauce (unopened), onions, \
        potatoes, garlic, bananas.
        FREEZER: frozen meals, ice cream, frozen vegetables, frozen fruit, frozen pizza, \
        frozen meat (anything the user says is frozen), ice, frozen waffles/pancakes, \
        frozen fish sticks, popsicles.
        When in doubt, default to FRIDGE — it is the safest default for perishables.

        CATEGORY RULES — use these exact categories:
        Produce: all fresh fruits and vegetables (apples, bananas, lettuce, tomatoes, onions, \
        potatoes, garlic, berries, avocados, herbs, etc.)
        Meat & Seafood: chicken, beef, pork, fish, shrimp, ground meat, steaks, sausage, bacon, \
        deli meats, turkey, lamb
        Dairy: milk, eggs, butter, cheese, yogurt, cream, sour cream, cream cheese
        Beverages: juice, soda, water, beer, wine, coffee, tea, kombucha
        Grains & Bread: bread, pasta, rice, tortillas, cereal, oats, flour, crackers, granola
        Canned & Jarred: canned beans, canned tomatoes, soup, salsa, pickles, olives, jam, \
        peanut butter, sauces
        Snacks: chips, cookies, nuts, dried fruit, chocolate, popcorn, candy, granola bars
        Condiments & Spices: ketchup, mustard, mayo, salt, pepper, spices, cooking oil, vinegar, \
        soy sauce, hot sauce, honey
        Frozen: frozen meals, frozen vegetables, frozen pizza, ice cream, frozen fruit, popsicles
        Baking: baking soda, baking powder, sugar, vanilla extract, cocoa powder
        Other: anything that doesn't clearly fit above
        IMPORTANT: Eggs are Dairy. Chicken is Meat & Seafood. Bread is Grains & Bread. \
        Never put meat in Dairy. Never put eggs in Produce.

        VOICE INPUT: The user may speak naturally about their kitchen items via voice. \
        Parse spoken descriptions like "I have milk, a dozen eggs, some chicken I bought yesterday" \
        into structured inventory additions. Use the storage and category rules above — do not guess. \
        Infer quantities from natural language: "a dozen" = 12, "a couple" = 2, "some" = 1. \
        Estimate purchase and expiration dates from context clues like "bought yesterday" or \
        "just got". After adding items, confirm conversationally: "Added milk, 12 eggs, and \
        chicken to your fridge. Chicken expires around April 5th. Sound right?" \
        Handle follow-up corrections naturally: "Actually move the eggs to the pantry" fires move_items. \
        If you can't parse the voice input clearly, ask for clarification rather than guessing wrong.

        LEARNED PATTERNS: When adding items the user has bought before, the system automatically \
        applies learned expiration dates from their past corrections. You don't need to guess \
        expiration for repeat items — just pass the name and let the system handle it. \
        For new items, always include your best expiration_days estimate.
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

    private static func buildPurchaseHistoryContext(modelContext: ModelContext) -> String {
        let descriptor = FetchDescriptor<PurchaseHistory>()
        guard let allHistory = try? modelContext.fetch(descriptor),
              !allHistory.isEmpty else {
            return "PURCHASE HISTORY: No items bought yet."
        }

        let topItems = allHistory
            .filter { !$0.isDismissed }
            .sorted { $0.rankingScore > $1.rankingScore }
            .prefix(10)

        if topItems.isEmpty {
            return "PURCHASE HISTORY: No frequently purchased items."
        }

        var lines: [String] = ["FREQUENTLY PURCHASED (by frequency × recency):"]
        for item in topItems {
            let daysAgo = Calendar.current.dateComponents(
                [.day], from: item.lastPurchaseDate, to: .now
            ).day ?? 0
            lines.append("- \(item.canonicalName) (\(item.purchaseCount)× bought, \(daysAgo)d ago, \(item.preferredStorage.displayName), ~\(Int(item.averageExpirationDays))d shelf life)")
        }

        return lines.joined(separator: "\n")
    }
}
