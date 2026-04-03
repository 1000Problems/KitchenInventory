//
//  VoiceItemParser.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/3/26.
//

import Foundation
import SwiftData

/// Parses a voice transcript into structured `ParsedItem` objects using Claude.
/// This is a lightweight, focused call separate from the chat tool loop —
/// it asks Claude to return JSON only, no tool calls.
final class VoiceItemParser {
    private let apiService = ClaudeAPIService()
    private let model = "claude-haiku-4-5"

    /// Parses a raw voice transcript into an array of parsed items.
    /// Uses Claude to understand natural language and categorize items.
    func parse(transcript: String, modelContext: ModelContext) async throws -> [ParsedItem] {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let systemPrompt = buildParsePrompt(modelContext: modelContext)
        let messages: [[String: Any]] = [
            ["role": "user", "content": transcript]
        ]

        let response = try await apiService.sendMessage(
            messages: messages,
            systemPrompt: systemPrompt,
            tools: [],
            model: model
        )

        return parseItemsFromResponse(response.textContent)
    }

    // MARK: - System Prompt

    private func buildParsePrompt(modelContext: ModelContext) -> String {
        // Pull learned storage preferences from purchase history
        var learnedPrefs = ""
        let historyDescriptor = FetchDescriptor<PurchaseHistory>()
        if let history = try? modelContext.fetch(historyDescriptor), !history.isEmpty {
            let prefs = history.prefix(20).map { "\($0.canonicalName) → \($0.preferredStorage.displayName)" }
            learnedPrefs = "\n\nLEARNED PREFERENCES (use these when available):\n\(prefs.joined(separator: "\n"))"
        }

        // Inject today's date so the model can compute absolute dates
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        let todayString = formatter.string(from: .now)

        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        let todayISO = isoFormatter.string(from: .now)

        return """
        You are a kitchen inventory parser. Your ONLY job is to extract grocery/food items from a voice transcript and return them as a JSON array.

        TODAY'S DATE: \(todayString) (\(todayISO))

        The user will speak in one of two formats:
        1. PURCHASE FORMAT: "I bought milk today" / "I got chicken last week" / "I bought eggs yesterday"
           → Set purchase_date to when they bought it. Calculate expiration_date from that purchase date + typical shelf life.
        2. EXPIRATION FORMAT: "I have milk that expires April 7th" / "Yogurt expiring tomorrow" / "Chicken expires in 3 days"
           → Set purchase_date to today. Set expiration_date to the date they stated.

        RULES:
        1. Return ONLY a JSON array. No explanation, no markdown, no code fences.
        2. Each item object has these fields:
           - "name": string (proper capitalized name, e.g. "Chicken Breast" not "chicken breast")
           - "category": string (one of: Produce, Meat & Seafood, Dairy, Beverages, Grains & Bread, Canned & Jarred, Snacks, Condiments & Spices, Frozen, Baking, Other)
           - "storage": string (one of: "pantry", "fridge", "freezer")
           - "quantity": number (default 1)
           - "unit": string (e.g. "item", "lb", "oz", "gallon", "dozen", "bag", "box", "can")
           - "purchase_date": string in "yyyy-MM-dd" format (when they bought it; default to today)
           - "expiration_date": string in "yyyy-MM-dd" format or null (absolute expiration date)

        DATE CALCULATION (CRITICAL — get this right):
        - "today" = \(todayISO)
        - "yesterday" = one day before today
        - "last week" = 7 days before today
        - "3 days ago" = 3 days before today
        - "April 7th" = 2026-04-07 (use the current year unless context suggests otherwise)
        - "tomorrow" = one day after today
        - "in 3 days" = 3 days after today
        - Always output dates as "yyyy-MM-dd" strings.

        EXPIRATION ESTIMATES (from purchase date, NOT from today):
        - Fresh produce: purchase_date + 5-7 days
        - Dairy (milk, yogurt): purchase_date + 7-14 days
        - Fresh meat/poultry: purchase_date + 3-5 days
        - Fresh fish: purchase_date + 2-3 days
        - Bread: purchase_date + 5-7 days
        - Eggs: purchase_date + 21-28 days
        - Canned goods: null (very long shelf life)
        - Frozen items: null (very long shelf life)
        - Pantry staples (rice, pasta, flour): null (very long shelf life)

        STORAGE RULES:
        - FRIDGE: milk, eggs, cheese, yogurt, butter, chicken, beef, pork, fish, fresh vegetables, fresh fruit, deli meat, tofu, hummus, salsa, fresh herbs, orange juice, leftovers
        - PANTRY: rice, pasta, canned goods, cereal, bread, chips, crackers, nuts, oil, vinegar, spices, flour, sugar, coffee, tea, honey, peanut butter, dried beans, oats
        - FREEZER: frozen vegetables, frozen fruit, ice cream, frozen pizza, frozen meals, frozen meat (if specified as frozen)

        CATEGORY RULES:
        - Eggs → Dairy. Chicken/Beef/Pork/Fish/Shrimp → Meat & Seafood. Rice/Pasta/Bread/Cereal → Grains & Bread.
        - Milk/Cheese/Yogurt/Butter/Cream → Dairy. Apples/Bananas/Lettuce/Tomatoes → Produce.
        - Chips/Crackers/Cookies → Snacks. Canned beans/soup/tuna → Canned & Jarred.
        - Salt/Pepper/Oregano/Soy Sauce/Ketchup/Mustard → Condiments & Spices.
        - Flour/Sugar/Baking Soda/Vanilla → Baking. Coffee/Tea/Juice/Soda/Water → Beverages.
        - Frozen peas/frozen pizza/ice cream → Frozen. Default to Fridge when in doubt.
        \(learnedPrefs)

        QUANTITY PARSING:
        - "a dozen eggs" → quantity: 12, unit: "item"
        - "two pounds of chicken" → quantity: 2, unit: "lb"
        - "a gallon of milk" → quantity: 1, unit: "gallon"
        - "some rice" → quantity: 1, unit: "bag"
        - If no quantity mentioned, default to 1 item.

        Ignore non-food items. If the transcript is unclear, do your best to extract what you can.
        """
    }

    // MARK: - Response Parsing

    /// ISO date formatter for parsing yyyy-MM-dd strings from the API response.
    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func parseItemsFromResponse(_ text: String) -> [ParsedItem] {
        // Strip any markdown code fences Claude might add despite instructions
        var cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Find the JSON array in the response
        if let startIdx = cleaned.firstIndex(of: "["),
           let endIdx = cleaned.lastIndex(of: "]") {
            cleaned = String(cleaned[startIdx...endIdx])
        }

        guard let data = cleaned.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("[VoiceItemParser] Failed to parse JSON from response: \(text)")
            return []
        }

        let dateFormatter = Self.isoDateFormatter

        return jsonArray.compactMap { dict -> ParsedItem? in
            guard let name = dict["name"] as? String, !name.isEmpty else { return nil }

            let category = dict["category"] as? String ?? "Other"
            let storageStr = (dict["storage"] as? String)?.lowercased() ?? "fridge"
            let storage = StorageLocation(rawValue: storageStr) ?? .fridge
            let quantity = dict["quantity"] as? Double ?? (dict["quantity"] as? Int).map { Double($0) } ?? 1
            let unit = dict["unit"] as? String ?? "item"

            // Parse absolute dates from the response
            let purchaseDate: Date
            if let dateStr = dict["purchase_date"] as? String,
               let parsed = dateFormatter.date(from: dateStr) {
                purchaseDate = parsed
            } else {
                purchaseDate = .now
            }

            let expirationDate: Date?
            if let dateStr = dict["expiration_date"] as? String,
               let parsed = dateFormatter.date(from: dateStr) {
                expirationDate = parsed
            } else {
                expirationDate = nil
            }

            return ParsedItem(
                name: name,
                category: category,
                storage: storage,
                quantity: max(0.01, quantity),
                unit: unit,
                expirationDate: expirationDate,
                purchaseDate: purchaseDate
            )
        }
    }
}
