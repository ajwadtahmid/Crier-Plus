import Foundation
import SwiftData

/// The Dismiss/Snooze logic shared by the in-app ring screen, the notification action buttons, and
/// `DismissAlarmIntent` (the system Stop control while the app isn't running). Opens its own
/// `ModelContext` per call rather than sharing the app's, since an `AppIntent` has no access to the
/// SwiftUI environment's container.
actor AlarmActionHandler {
    static let snoozeDuration: TimeInterval = 10 * 60

    private let alarmService: AlarmKitService
    private let notificationService: NotificationService
    private let makeModelContainer: @Sendable () throws -> ModelContainer

    init(
        alarmService: AlarmKitService = AlarmKitService(),
        notificationService: NotificationService = NotificationService(),
        makeModelContainer: @escaping @Sendable () throws -> ModelContainer = { CrierPlusModelContainer.shared }
    ) {
        self.alarmService = alarmService
        self.notificationService = notificationService
        self.makeModelContainer = makeModelContainer
    }

    /// Deactivates a one-time reminder; leaves a repeating one active since its next occurrence is
    /// already correctly armed (by AlarmKit itself, or by the notification path's repeating trigger).
    @discardableResult
    func dismiss(reminderID: UUID, path: SchedulingPath) async throws -> Bool {
        if path == .alarm {
            try? await alarmService.stop(for: reminderID)
        }

        let context = try ModelContext(makeModelContainer())
        guard let reminder = try Self.fetchReminder(id: reminderID, context: context) else { return false }

        if reminder.repeatPattern == .none {
            reminder.isActive = false
            try context.save()
        }
        return true
    }

    /// Alarm-path snooze is the system's own countdown transition (triggered the same way its
    /// secondary button would); notification-path snooze schedules a one-off follow-up.
    @discardableResult
    func snooze(reminderID: UUID, path: SchedulingPath) async throws -> Bool {
        switch path {
        case .alarm:
            try await alarmService.countdown(for: reminderID)
            return true
        case .notification:
            let context = try ModelContext(makeModelContainer())
            guard let reminder = try Self.fetchReminder(id: reminderID, context: context) else { return false }
            try await notificationService.scheduleSnooze(
                ReminderSchedulingPayload(reminder),
                after: Self.snoozeDuration
            )
            return true
        }
    }

    private static func fetchReminder(id: UUID, context: ModelContext) throws -> Reminder? {
        var descriptor = FetchDescriptor<Reminder>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
