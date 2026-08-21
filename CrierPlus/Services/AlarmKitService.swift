import AlarmKit
import Foundation
import SwiftUI

/// Seam over `AlarmManager` so tests can substitute a fake without hardware or alarm authorization.
/// `scheduleAlarm` wraps the real `schedule(id:configuration:) -> Alarm` and discards its result —
/// `Alarm` has no public initializer beyond `Decodable` and `AlarmConfiguration` exposes no
/// readable properties, so a fake can't fabricate or inspect either; nothing in this app reads the
/// returned `Alarm` anyway.
protocol AlarmManagerProtocol: Sendable {
    var authorizationState: AlarmManager.AuthorizationState { get }
    @discardableResult
    func requestAuthorization() async throws -> AlarmManager.AuthorizationState
    func scheduleAlarm<Metadata: AlarmMetadata>(
        id: Alarm.ID,
        configuration: AlarmManager.AlarmConfiguration<Metadata>
    ) async throws
    func cancel(id: Alarm.ID) throws
    func stop(id: Alarm.ID) throws
    func countdown(id: Alarm.ID) throws
}

/// `AlarmManager` isn't declared `Sendable` in the shipped SDK, but `.shared` is a process-wide
/// singleton backed by an XPC connection to a system daemon, so its own internal synchronization
/// already makes cross-actor use safe.
extension AlarmManager: @retroactive @unchecked Sendable {}
extension AlarmManager: AlarmManagerProtocol {
    func scheduleAlarm<Metadata: AlarmMetadata>(
        id: Alarm.ID,
        configuration: AlarmManager.AlarmConfiguration<Metadata>
    ) async throws {
        _ = try await schedule(id: id, configuration: configuration)
    }
}

actor AlarmKitService {
    /// The alert's secondary button starts a 10-minute countdown handled entirely by the system —
    /// matching Phase 7's planned 10-minute snooze without any app-side reschedule logic.
    static let snoozeDuration: TimeInterval = 10 * 60

    private let manager: any AlarmManagerProtocol

    init(manager: any AlarmManagerProtocol = AlarmManager.shared) {
        self.manager = manager
    }

    var authorizationState: AlarmManager.AuthorizationState {
        manager.authorizationState
    }

    @discardableResult
    func requestAuthorization() async throws -> AlarmManager.AuthorizationState {
        try await manager.requestAuthorization()
    }

    func schedule(_ reminder: ReminderSchedulingPayload) async throws {
        let dismissButton = AlarmButton(text: "Dismiss", textColor: .white, systemImageName: "stop.fill")
        let snoozeButton = AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz")
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: reminder.title),
            stopButton: dismissButton,
            secondaryButton: snoozeButton,
            secondaryButtonBehavior: .countdown
        )
        let countdown = AlarmPresentation.Countdown(title: "Snoozed")
        let attributes = AlarmAttributes<EmptyAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert, countdown: countdown),
            metadata: nil,
            tintColor: .appPrimary
        )
        let configuration = AlarmManager.AlarmConfiguration<EmptyAlarmMetadata>(
            countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: Self.snoozeDuration),
            schedule: Self.schedule(
                repeatPattern: reminder.repeatPattern,
                repeatDays: reminder.repeatDays,
                scheduledTime: reminder.scheduledTime
            ),
            attributes: attributes,
            stopIntent: DismissAlarmIntent(reminderID: reminder.id),
            secondaryIntent: nil,
            sound: .default
        )

        try await manager.scheduleAlarm(id: reminder.id, configuration: configuration)
    }

    func cancel(for reminderID: UUID) throws {
        try manager.cancel(id: reminderID)
    }

    /// Mirrors what tapping the alert's system Stop control does — used when the user dismisses
    /// from `AlarmRingView` while the app happens to be in the foreground.
    func stop(for reminderID: UUID) throws {
        try manager.stop(id: reminderID)
    }

    /// Mirrors what tapping the alert's secondary (snooze) control does — used when the user
    /// snoozes from `AlarmRingView` while the app happens to be in the foreground.
    func countdown(for reminderID: UUID) throws {
        try manager.countdown(id: reminderID)
    }
}

extension AlarmKitService {
    /// Unlike `NotificationTriggerPlanner` (which needs one trigger per weekday), AlarmKit's
    /// `.weekly` recurrence takes the whole day set directly, so every repeat pattern maps to a
    /// single `Alarm`.
    static func schedule(
        repeatPattern: RepeatPattern,
        repeatDays: [Int],
        scheduledTime: Date,
        calendar: Calendar = .current
    ) -> Alarm.Schedule {
        switch repeatPattern {
        case .none:
            return .fixed(scheduledTime)
        case .daily:
            return .relative(weeklyRelative(days: Array(1...7), scheduledTime: scheduledTime, calendar: calendar))
        case .weekdays:
            return .relative(weeklyRelative(days: Array(2...6), scheduledTime: scheduledTime, calendar: calendar))
        case .weekly:
            let weekday = calendar.component(.weekday, from: scheduledTime)
            return .relative(weeklyRelative(days: [weekday], scheduledTime: scheduledTime, calendar: calendar))
        case .custom:
            return .relative(weeklyRelative(days: repeatDays, scheduledTime: scheduledTime, calendar: calendar))
        }
    }

    private static func weeklyRelative(
        days: [Int],
        scheduledTime: Date,
        calendar: Calendar
    ) -> Alarm.Schedule.Relative {
        let components = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        let time = Alarm.Schedule.Relative.Time(hour: components.hour ?? 0, minute: components.minute ?? 0)
        return Alarm.Schedule.Relative(time: time, repeats: .weekly(days.compactMap(localeWeekday(from:))))
    }

    /// `Calendar`'s 1-based weekday convention (1 = Sunday ... 7 = Saturday) mapped to `Locale.Weekday`.
    private static func localeWeekday(from weekday: Int) -> Locale.Weekday? {
        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }
}
