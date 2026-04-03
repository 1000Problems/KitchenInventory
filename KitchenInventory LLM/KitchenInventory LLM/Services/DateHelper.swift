//
//  DateHelper.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import Foundation

struct DateHelper {
    static let pacificTimeZone = TimeZone(identifier: "America/Los_Angeles")!

    // MARK: - Formatters

    static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        f.timeZone = pacificTimeZone
        return f
    }()

    static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeZone = pacificTimeZone
        return f
    }()

    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = pacificTimeZone
        return f
    }()

    static let dayOfWeekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.timeZone = pacificTimeZone
        return f
    }()

    // MARK: - Helpers

    static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    static func fullDate(_ date: Date) -> String {
        fullDateFormatter.string(from: date)
    }

    static func isoDate(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func dayOfWeek(_ date: Date) -> String {
        dayOfWeekFormatter.string(from: date).uppercased()
    }

    static func dayNumber(_ date: Date) -> Int {
        Calendar.current.component(.day, from: date)
    }

    static func dateFromISO(_ string: String) -> Date? {
        isoFormatter.date(from: string)
    }

    /// Returns a date relative to today
    static func daysFromNow(_ days: Int) -> Date {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: .now)) else {
            // Fallback: should never happen with standard calendar, but avoids force unwrap
            return Calendar.current.startOfDay(for: .now)
        }
        return date
    }

    /// Relative description like "Today", "Tomorrow", "In 3 days", "2 days ago"
    static func relativeDescription(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: date)).day ?? 0
        switch days {
        case ..<(-1): return "\(abs(days)) days ago"
        case -1: return "Yesterday"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }
}
