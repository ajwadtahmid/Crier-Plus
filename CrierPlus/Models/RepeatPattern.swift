import Foundation

enum RepeatPattern: String, Codable, CaseIterable, Sendable {
    case none
    case daily
    case weekdays
    case weekly
    case custom
}

extension RepeatPattern {
    /// Weekday numbers use `Calendar`'s 1-based convention (1 = Sunday ... 7 = Saturday).
    func scheduleDescription(
        repeatDays: [Int] = [],
        scheduledTime: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        switch self {
        case .daily:
            return "Every day"
        case .weekdays:
            return "Weekdays"
        case .weekly:
            return "Weekly"
        case .custom:
            return Self.customDaysDescription(repeatDays, calendar: calendar)
        case .none:
            let day = Self.dayString(from: scheduledTime, calendar: calendar)
            return scheduledTime < now ? "Expired · \(day)" : day
        }
    }

    private static func customDaysDescription(_ repeatDays: [Int], calendar: Calendar) -> String {
        guard !repeatDays.isEmpty else { return "Custom" }
        let symbols = calendar.shortWeekdaySymbols
        return repeatDays
            .sorted()
            .compactMap { symbols.indices.contains($0 - 1) ? symbols[$0 - 1] : nil }
            .joined(separator: ", ")
    }

    private static func dayString(from date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
