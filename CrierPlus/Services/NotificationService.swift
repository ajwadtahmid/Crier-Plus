import AVFoundation
import Foundation
import UserNotifications

/// A single scheduling unit for one occurrence of a repeat pattern — e.g. "weekdays" expands to
/// five of these (one per weekday), while "daily" and "one-shot" each need only one.
struct NotificationTriggerPlan: Equatable {
    let identifierSuffix: String
    let dateComponents: DateComponents
    let repeats: Bool
}

enum NotificationTriggerPlanner {
    /// Weekday numbers use `Calendar`'s 1-based convention (1 = Sunday ... 7 = Saturday).
    static let weekdayRange = 2...6

    static func plans(
        repeatPattern: RepeatPattern,
        repeatDays: [Int],
        scheduledTime: Date,
        calendar: Calendar = .current
    ) -> [NotificationTriggerPlan] {
        let timeOfDay = calendar.dateComponents([.hour, .minute], from: scheduledTime)

        switch repeatPattern {
        case .none:
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: scheduledTime
            )
            return [NotificationTriggerPlan(identifierSuffix: "one-shot", dateComponents: components, repeats: false)]

        case .daily:
            return [NotificationTriggerPlan(identifierSuffix: "daily", dateComponents: timeOfDay, repeats: true)]

        case .weekdays:
            return weekdayRange.map { weekday in
                var components = timeOfDay
                components.weekday = weekday
                return NotificationTriggerPlan(
                    identifierSuffix: "weekday-\(weekday)",
                    dateComponents: components,
                    repeats: true
                )
            }

        case .weekly:
            var components = timeOfDay
            components.weekday = calendar.component(.weekday, from: scheduledTime)
            return [NotificationTriggerPlan(identifierSuffix: "weekly", dateComponents: components, repeats: true)]

        case .custom:
            return repeatDays.sorted().map { day in
                var components = timeOfDay
                components.weekday = day
                return NotificationTriggerPlan(
                    identifierSuffix: "custom-\(day)",
                    dateComponents: components,
                    repeats: true
                )
            }
        }
    }
}

struct NotificationScheduleResult: Equatable {
    let requestIdentifiers: [String]
    let soundWarning: CustomSoundResolution?
}

/// A `Sendable` snapshot of the reminder fields scheduling needs. `Reminder` itself is a
/// SwiftData `@Model` class and isn't `Sendable`, so callers build this on their own isolation
/// domain before crossing into the scheduler/notification actors.
struct ReminderSchedulingPayload: Sendable {
    let id: UUID
    let title: String
    let spokenMessage: String
    let scheduledTime: Date
    let repeatPattern: RepeatPattern
    let repeatDays: [Int]
    let audioFilePath: String?

    init(
        id: UUID,
        title: String,
        spokenMessage: String,
        scheduledTime: Date,
        repeatPattern: RepeatPattern,
        repeatDays: [Int],
        audioFilePath: String?
    ) {
        self.id = id
        self.title = title
        self.spokenMessage = spokenMessage
        self.scheduledTime = scheduledTime
        self.repeatPattern = repeatPattern
        self.repeatDays = repeatDays
        self.audioFilePath = audioFilePath
    }

    init(_ reminder: Reminder) {
        self.init(
            id: reminder.id,
            title: reminder.title,
            spokenMessage: reminder.spokenMessage,
            scheduledTime: reminder.scheduledTime,
            repeatPattern: reminder.repeatPattern,
            repeatDays: reminder.repeatDays,
            audioFilePath: reminder.audioFilePath
        )
    }
}

/// Seam over `UNUserNotificationCenter` so tests can substitute an in-memory fake. The real
/// center's pending-request round trip depends on the system notification daemon, which isn't
/// reliably observable from within an `.xctest` test host in the Simulator — a real environment
/// limitation, not something a delay/retry works around.
protocol NotificationCenterProtocol: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}

extension UNUserNotificationCenter: NotificationCenterProtocol {}

actor NotificationService {
    static let categoryIdentifier = "REMINDER_CATEGORY"
    static let snoozeActionIdentifier = "SNOOZE_ACTION"
    static let dismissActionIdentifier = "DISMISS_ACTION"

    private let center: any NotificationCenterProtocol

    init(center: any NotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    static func registerCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: snoozeActionIdentifier,
            title: "Snooze",
            options: []
        )
        let dismissAction = UNNotificationAction(
            identifier: dismissActionIdentifier,
            title: "Dismiss",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [snoozeAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    @discardableResult
    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// A live system status read for the Settings permission row — not part of `NotificationCenterProtocol`
    /// since `UNNotificationSettings` has no public initializer for a fake to construct, and this
    /// display-only read isn't exercised by any test (the 🧑 checkpoint covers it manually).
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    func schedule(_ reminder: ReminderSchedulingPayload) async throws -> NotificationScheduleResult {
        await cancel(for: reminder.id)

        let (soundName, soundWarning) = try await CustomSoundInstaller.resolveSound(for: reminder)

        let plans = NotificationTriggerPlanner.plans(
            repeatPattern: reminder.repeatPattern,
            repeatDays: reminder.repeatDays,
            scheduledTime: reminder.scheduledTime
        )

        var identifiers: [String] = []
        for plan in plans {
            let identifier = "\(reminder.id.uuidString)-\(plan.identifierSuffix)"
            let content = Self.makeContent(for: reminder, soundName: soundName)
            let trigger = UNCalendarNotificationTrigger(dateMatching: plan.dateComponents, repeats: plan.repeats)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try await center.add(request)
            identifiers.append(identifier)
        }

        return NotificationScheduleResult(requestIdentifiers: identifiers, soundWarning: soundWarning)
    }

    /// A single one-off follow-up reusing the reminder's existing sound, fired `interval` seconds
    /// out — used by the Snooze action instead of touching the reminder's normal recurring
    /// schedule. The identifier still carries the reminder's UUID prefix, so a subsequent `cancel`
    /// or reschedule sweeps this up along with everything else for that reminder.
    @discardableResult
    func scheduleSnooze(
        _ reminder: ReminderSchedulingPayload,
        after interval: TimeInterval
    ) async throws -> NotificationScheduleResult {
        let (soundName, soundWarning) = try await CustomSoundInstaller.resolveSound(for: reminder)

        let identifier = "\(reminder.id.uuidString)-snooze"
        let content = Self.makeContent(for: reminder, soundName: soundName)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await center.add(request)

        return NotificationScheduleResult(requestIdentifiers: [identifier], soundWarning: soundWarning)
    }

    func cancel(for reminderID: UUID) async {
        let pending = await center.pendingNotificationRequests()
        let prefix = reminderID.uuidString
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        guard !identifiers.isEmpty else { return }
        await center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingIdentifiers(for reminderID: UUID) async -> [String] {
        let pending = await center.pendingNotificationRequests()
        let prefix = reminderID.uuidString
        return pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
    }
}

extension NotificationService {
    private static func makeContent(
        for reminder: ReminderSchedulingPayload,
        soundName: String?
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.spokenMessage
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = ["reminderID": reminder.id.uuidString]
        content.sound = soundName.map { UNNotificationSound(named: UNNotificationSoundName($0)) } ?? .default
        return content
    }

}
