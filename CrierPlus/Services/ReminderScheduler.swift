import Foundation

/// The only entry point views use to schedule or cancel a reminder. For now this only has the
/// notification path behind it; Phase 6B adds AlarmKit as the authorized-primary path without
/// changing any call site here.
actor ReminderScheduler {
    private let notificationService: NotificationService

    init(notificationService: NotificationService = NotificationService()) {
        self.notificationService = notificationService
    }

    @discardableResult
    func schedule(_ reminder: ReminderSchedulingPayload) async throws -> NotificationScheduleResult {
        try await notificationService.schedule(reminder)
    }

    func cancel(for reminderID: UUID) async {
        await notificationService.cancel(for: reminderID)
    }
}
