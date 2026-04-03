//
//  ToolRegistry.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import Foundation
import SwiftData

// MARK: - Tool Protocol

protocol KitchenTool {
    var name: String { get }
    var description: String { get }
    var inputSchema: [String: AnyCodable] { get }
    func execute(params: [String: Any], context: ModelContext) throws -> String
}

// MARK: - Tool Registry

struct ToolRegistry {
    static let allTools: [KitchenTool] = [
        GetInventoryTool(),
        AddItemsTool(),
        RemoveItemsTool(),
        MoveItemsTool(),
        UpdateExpirationTool(),
        ConsumeItemsTool(),
        GetPurchaseHistoryTool()
    ]

    static var toolDefinitions: [LLMToolDefinition] {
        allTools.map { tool in
            LLMToolDefinition(
                name: tool.name,
                description: tool.description,
                inputSchema: tool.inputSchema
            )
        }
    }

    static func execute(toolCall: ToolCall, context: ModelContext) throws -> ToolResult {
        guard let tool = allTools.first(where: { $0.name == toolCall.name }) else {
            return ToolResult(
                toolUseId: toolCall.id,
                content: "Unknown tool: \(toolCall.name)",
                isError: true
            )
        }

        do {
            let result = try tool.execute(params: toolCall.input, context: context)
            return ToolResult(toolUseId: toolCall.id, content: result, isError: false)
        } catch {
            return ToolResult(toolUseId: toolCall.id, content: "Error: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - Helper for building JSON schemas

private func schema(
    type: String,
    properties: [String: [String: Any]] = [:],
    required: [String] = []
) -> [String: AnyCodable] {
    var s: [String: AnyCodable] = [
        "type": AnyCodable(type)
    ]
    if !properties.isEmpty {
        s["properties"] = AnyCodable(properties)
    }
    if !required.isEmpty {
        s["required"] = AnyCodable(required)
    }
    return s
}

// MARK: - Fetch helpers

private func fetchActiveItems(context: ModelContext) throws -> [InventoryItem] {
    let descriptor = FetchDescriptor<InventoryItem>(
        predicate: #Predicate { !$0.isConsumed }
    )
    return try context.fetch(descriptor)
}

private func itemToJSON(_ item: InventoryItem) -> [String: Any] {
    var dict: [String: Any] = [
        "name": item.name,
        "category": item.category,
        "storage": item.storageLocation.displayName,
        "quantity": item.quantity,
        "unit": item.unit,
        "purchaseDate": DateHelper.isoDate(item.purchaseDate)
    ]
    if let exp = item.effectiveExpiration {
        dict["expiration"] = DateHelper.isoDate(exp)
        dict["daysLeft"] = item.daysUntilExpiration ?? 0
    }
    if item.isExpired {
        dict["expired"] = true
    }
    return dict
}

// MARK: - 1. GetInventory

struct GetInventoryTool: KitchenTool {
    let name = "get_inventory"
    let description = "Get current kitchen inventory. Can filter by storage location, category, expiring soon, or search by name."

    var inputSchema: [String: AnyCodable] {
        schema(type: "object", properties: [
            "location": ["type": "string", "enum": ["pantry", "fridge", "freezer"], "description": "Filter by storage location"],
            "search": ["type": "string", "description": "Search items by name (case-insensitive)"],
            "expiring_soon": ["type": "boolean", "description": "If true, only return items expiring within 3 days"],
            "expired": ["type": "boolean", "description": "If true, only return expired items"]
        ])
    }

    func execute(params: [String: Any], context: ModelContext) throws -> String {
        var items = try fetchActiveItems(context: context)

        // Apply filters
        if let location = params["location"] as? String {
            items = items.filter { $0.storageLocationRaw == location.lowercased() }
        }
        if let search = params["search"] as? String, !search.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(search) }
        }
        if let expiringSoon = params["expiring_soon"] as? Bool, expiringSoon {
            items = items.filter { $0.isExpiringSoon || $0.isExpired }
        }
        if let expired = params["expired"] as? Bool, expired {
            items = items.filter { $0.isExpired }
        }

        if items.isEmpty {
            return "No items found matching your criteria."
        }

        let itemDicts = items.map { itemToJSON($0) }
        let data = try JSONSerialization.data(withJSONObject: itemDicts, options: .prettyPrinted)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

// MARK: - 2. AddItems

struct AddItemsTool: KitchenTool {
    let name = "add_items"
    let description = "Add one or more items to the kitchen inventory."

    var inputSchema: [String: AnyCodable] {
        schema(type: "object", properties: [
            "items": [
                "type": "array",
                "description": "Array of items to add",
                "items": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Item name"],
                        "storage": ["type": "string", "enum": ["pantry", "fridge", "freezer"], "description": "Storage location"],
                        "category": ["type": "string", "description": "Category (e.g., Dairy, Produce, Meat)"],
                        "quantity": ["type": "number", "description": "Quantity (default 1)"],
                        "unit": ["type": "string", "description": "Unit (e.g., item, lb, oz, gallon)"],
                        "expiration_days": ["type": "integer", "description": "Days until expiration from today"]
                    ] as [String: Any],
                    "required": ["name"]
                ] as [String: Any]
            ]
        ], required: ["items"])
    }

    func execute(params: [String: Any], context: ModelContext) throws -> String {
        guard let itemsArray = params["items"] as? [[String: Any]] else {
            return "Error: 'items' array is required."
        }

        var added: [String] = []

        for itemData in itemsArray {
            guard let name = itemData["name"] as? String else { continue }

            let storageRaw = (itemData["storage"] as? String)?.lowercased() ?? "fridge"
            let storage = StorageLocation(rawValue: storageRaw) ?? .fridge
            let category = itemData["category"] as? String ?? "Other"
            let quantity = itemData["quantity"] as? Double ?? 1
            let unit = itemData["unit"] as? String ?? "item"
            let expirationDays = itemData["expiration_days"] as? Int

            let item = InventoryItem(
                name: name,
                category: category,
                storageLocation: storage,
                purchaseDate: .now,
                estimatedExpiration: expirationDays.map { DateHelper.daysFromNow($0) },
                quantity: quantity,
                unit: unit
            )

            context.insert(item)

            // Upsert purchase history
            upsertPurchaseHistory(
                name: name,
                storage: storage,
                category: category,
                expirationDays: expirationDays,
                context: context
            )

            added.append(name)
        }

        try context.save()
        return "Added \(added.count) item(s): \(added.joined(separator: ", "))"
    }

    private func upsertPurchaseHistory(
        name: String,
        storage: StorageLocation,
        category: String,
        expirationDays: Int?,
        context: ModelContext
    ) {
        let canonicalName = name.lowercased().trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<PurchaseHistory>(
            predicate: #Predicate { $0.canonicalName == canonicalName }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.purchaseCount += 1
            existing.lastPurchaseDate = .now
            existing.preferredStorage = storage
            if let days = expirationDays {
                let total = existing.averageExpirationDays * Double(existing.purchaseCount - 1) + Double(days)
                existing.averageExpirationDays = total / Double(existing.purchaseCount)
            }
        } else {
            let history = PurchaseHistory(
                canonicalName: canonicalName,
                preferredStorage: storage,
                averageExpirationDays: Double(expirationDays ?? 7),
                category: category
            )
            context.insert(history)
        }
    }
}

// MARK: - 3. RemoveItems

struct RemoveItemsTool: KitchenTool {
    let name = "remove_items"
    let description = "Remove items from inventory by marking them as consumed/discarded. Can remove by name or remove all expired items."

    var inputSchema: [String: AnyCodable] {
        schema(type: "object", properties: [
            "names": [
                "type": "array",
                "items": ["type": "string"],
                "description": "Item names to remove"
            ] as [String: Any],
            "remove_expired": ["type": "boolean", "description": "If true, remove all expired items"]
        ])
    }

    func execute(params: [String: Any], context: ModelContext) throws -> String {
        let items = try fetchActiveItems(context: context)
        var removed: [String] = []

        if let removeExpired = params["remove_expired"] as? Bool, removeExpired {
            let expiredItems = items.filter { $0.isExpired }
            for item in expiredItems {
                item.isConsumed = true
                removed.append(item.name)
            }
        }

        if let names = params["names"] as? [String] {
            for name in names {
                if let item = items.first(where: { $0.name.localizedCaseInsensitiveContains(name) && !$0.isConsumed }) {
                    item.isConsumed = true
                    removed.append(item.name)
                }
            }
        }

        try context.save()

        if removed.isEmpty {
            return "No matching items found to remove."
        }
        return "Removed \(removed.count) item(s): \(removed.joined(separator: ", "))"
    }
}

// MARK: - 4. MoveItems

struct MoveItemsTool: KitchenTool {
    let name = "move_items"
    let description = "Move items to a different storage location (pantry, fridge, or freezer)."

    var inputSchema: [String: AnyCodable] {
        schema(type: "object", properties: [
            "names": [
                "type": "array",
                "items": ["type": "string"],
                "description": "Item names to move"
            ] as [String: Any],
            "destination": ["type": "string", "enum": ["pantry", "fridge", "freezer"], "description": "Target storage location"]
        ], required: ["names", "destination"])
    }

    func execute(params: [String: Any], context: ModelContext) throws -> String {
        guard let names = params["names"] as? [String],
              let destRaw = params["destination"] as? String,
              let destination = StorageLocation(rawValue: destRaw.lowercased())
        else {
            return "Error: 'names' and 'destination' are required."
        }

        let items = try fetchActiveItems(context: context)
        var moved: [String] = []

        for name in names {
            if let item = items.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) {
                item.storageLocation = destination
                moved.append("\(item.name) → \(destination.displayName)")
            }
        }

        try context.save()

        if moved.isEmpty {
            return "No matching items found to move."
        }
        return "Moved \(moved.count) item(s): \(moved.joined(separator: ", "))"
    }
}

// MARK: - 5. UpdateExpiration

struct UpdateExpirationTool: KitchenTool {
    let name = "update_expiration"
    let description = "Update the expiration date for an item."

    var inputSchema: [String: AnyCodable] {
        schema(type: "object", properties: [
            "name": ["type": "string", "description": "Item name"],
            "expiration_date": ["type": "string", "description": "New expiration date in YYYY-MM-DD format"]
        ], required: ["name", "expiration_date"])
    }

    func execute(params: [String: Any], context: ModelContext) throws -> String {
        guard let name = params["name"] as? String,
              let dateStr = params["expiration_date"] as? String,
              let newDate = DateHelper.dateFromISO(dateStr)
        else {
            return "Error: Valid 'name' and 'expiration_date' (YYYY-MM-DD) are required."
        }

        let items = try fetchActiveItems(context: context)

        guard let item = items.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) else {
            return "Item '\(name)' not found in inventory."
        }

        item.userExpiration = newDate
        try context.save()

        return "Updated \(item.name) expiration to \(DateHelper.shortDate(newDate))."
    }
}

// MARK: - 6. ConsumeItems

struct ConsumeItemsTool: KitchenTool {
    let name = "consume_items"
    let description = "Reduce the quantity of an item (partial use) or mark it fully consumed."

    var inputSchema: [String: AnyCodable] {
        schema(type: "object", properties: [
            "name": ["type": "string", "description": "Item name"],
            "quantity": ["type": "number", "description": "Quantity to consume. If >= current quantity, item is fully consumed."]
        ], required: ["name"])
    }

    func execute(params: [String: Any], context: ModelContext) throws -> String {
        guard let name = params["name"] as? String else {
            return "Error: 'name' is required."
        }

        let items = try fetchActiveItems(context: context)
        guard let item = items.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) else {
            return "Item '\(name)' not found in inventory."
        }

        let consumeQty = params["quantity"] as? Double ?? item.quantity

        if consumeQty >= item.quantity {
            item.isConsumed = true
            try context.save()
            return "Fully consumed \(item.name)."
        } else {
            item.quantity -= consumeQty
            try context.save()
            return "Used \(consumeQty) \(item.unit) of \(item.name). \(item.quantity) \(item.unit) remaining."
        }
    }
}

// MARK: - 7. GetPurchaseHistory

struct GetPurchaseHistoryTool: KitchenTool {
    let name = "get_purchase_history"
    let description = "Get the user's purchase history, showing frequently bought items ranked by frequency and recency."

    var inputSchema: [String: AnyCodable] {
        schema(type: "object", properties: [
            "limit": ["type": "integer", "description": "Maximum number of results (default 10)"]
        ])
    }

    func execute(params: [String: Any], context: ModelContext) throws -> String {
        let limit = params["limit"] as? Int ?? 10
        let descriptor = FetchDescriptor<PurchaseHistory>()
        let allHistory = try context.fetch(descriptor)

        if allHistory.isEmpty {
            return "No purchase history yet. The user hasn't added any items."
        }

        let ranked = allHistory
            .filter { !$0.isDismissed }
            .sorted { $0.rankingScore > $1.rankingScore }
            .prefix(limit)

        let results: [[String: Any]] = ranked.map { item in
            [
                "name": item.canonicalName,
                "timesOrdered": item.purchaseCount,
                "lastPurchased": DateHelper.isoDate(item.lastPurchaseDate),
                "preferredStorage": item.preferredStorage.displayName,
                "category": item.category,
                "avgExpirationDays": Int(item.averageExpirationDays)
            ]
        }

        let data = try JSONSerialization.data(withJSONObject: Array(results), options: .prettyPrinted)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
