import Foundation

enum ReminderFormValidationError: Equatable {
    case titleRequired
    case messageTooLong
    case customRepeatRequiresADay
    case scheduledTimeMustBeInFuture
}

enum ReminderFormValidator {
    static let messageCharacterLimit = 200

    static func validate(
        title: String,
        message: String,
        scheduledTime: Date,
        repeatPattern: RepeatPattern,
        repeatDays: [Int],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ReminderFormValidationError] {
        var errors: [ReminderFormValidationError] = []

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.titleRequired)
        }
        if message.count > messageCharacterLimit {
            errors.append(.messageTooLong)
        }
        if repeatPattern == .custom && repeatDays.isEmpty {
            errors.append(.customRepeatRequiresADay)
        }
        // Compared to the minute, not the exact second: a time picker only offers
        // minute granularity, so comparing against the live second-precise clock would
        // reject a genuinely-future minute whenever "now" itself has rolled past :00
        // (e.g. picking 11:06 at 11:05:30 is one minute out, not thirty seconds).
        // Repeating reminders only use the time-of-day component, so an "expired"
        // calendar date doesn't apply to them — only a one-time reminder can be
        // scheduled in the past.
        if repeatPattern == .none,
            calendar.compare(scheduledTime, to: now, toGranularity: .minute) == .orderedAscending
        {
            errors.append(.scheduledTimeMustBeInFuture)
        }

        return errors
    }
}
