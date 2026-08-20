import Foundation

/// Which delivery mechanism a reminder actually rang through, so the list/form can show it.
enum SchedulingPath: Equatable, Sendable {
    case alarm
    case notification
}

struct ReminderSchedulingOutcome: Equatable, Sendable {
    let path: SchedulingPath
    let soundWarning: CustomSoundResolution?
}

/// The only entry point views use to schedule or cancel a reminder. AlarmKit is the primary path
/// when authorized (it rings through Silent mode/Focus); the notification path from Phase 6A is
/// the fallback when it isn't. Every `schedule` call re-checks authorization and cancels whichever
/// path isn't chosen, so switching authorization between calls (e.g. after an edit) reissues the
/// correct path instead of leaving a stale alarm/notification behind.
actor ReminderScheduler {
    private let alarmService: AlarmKitService
    private let notificationService: NotificationService

    init(
        alarmService: AlarmKitService = AlarmKitService(),
        notificationService: NotificationService = NotificationService()
    ) {
        self.alarmService = alarmService
        self.notificationService = notificationService
    }

    @discardableResult
    func schedule(_ reminder: ReminderSchedulingPayload) async throws -> ReminderSchedulingOutcome {
        await cancel(for: reminder.id)

        if await alarmService.authorizationState == .authorized {
            try await alarmService.schedule(reminder)
            return ReminderSchedulingOutcome(path: .alarm, soundWarning: nil)
        }

        let result = try await notificationService.schedule(reminder)
        return ReminderSchedulingOutcome(path: .notification, soundWarning: result.soundWarning)
    }

    func cancel(for reminderID: UUID) async {
        try? await alarmService.cancel(for: reminderID)
        await notificationService.cancel(for: reminderID)
    }

    /// The path a newly-scheduled reminder would take right now, given current authorization —
    /// used by the list to show an up-to-date indicator without waiting for a save.
    func currentPath() async -> SchedulingPath {
        await alarmService.authorizationState == .authorized ? .alarm : .notification
    }
}
