import Foundation
import Testing

@testable import CrierPlus

struct ReminderSchedulerTests {
    private func makePayload(id: UUID = UUID()) -> ReminderSchedulingPayload {
        ReminderSchedulingPayload(
            id: id,
            title: "Test Reminder",
            spokenMessage: "This is a test.",
            scheduledTime: .now.addingTimeInterval(3600),
            repeatPattern: .none,
            repeatDays: [],
            audioFilePath: nil
        )
    }

    @Test
    func schedulingWhenAlarmAuthorizedUsesTheAlarmPath() async throws {
        let alarmManager = FakeAlarmManager(authorizationState: .authorized)
        let scheduler = ReminderScheduler(
            alarmService: AlarmKitService(manager: alarmManager),
            notificationService: NotificationService(center: FakeNotificationCenter())
        )
        let payload = makePayload()

        let outcome = try await scheduler.schedule(payload)
        #expect(outcome.path == .alarm)
        #expect(alarmManager.scheduledAlarmIDs.contains(payload.id))
    }

    @Test
    func schedulingWhenAlarmDeniedFallsBackToNotifications() async throws {
        let alarmManager = FakeAlarmManager(authorizationState: .denied)
        let notificationCenter = FakeNotificationCenter()
        let scheduler = ReminderScheduler(
            alarmService: AlarmKitService(manager: alarmManager),
            notificationService: NotificationService(center: notificationCenter)
        )
        let payload = makePayload()

        let outcome = try await scheduler.schedule(payload)
        #expect(outcome.path == .notification)
        let pending = await notificationCenter.pendingNotificationRequests()
        #expect(!pending.isEmpty)
    }

    @Test
    func switchingAuthorizationBetweenSavesReissuesTheCorrectPathWithNoDoubleFire() async throws {
        let alarmManager = FakeAlarmManager(authorizationState: .authorized)
        let notificationCenter = FakeNotificationCenter()
        let scheduler = ReminderScheduler(
            alarmService: AlarmKitService(manager: alarmManager),
            notificationService: NotificationService(center: notificationCenter)
        )
        let payload = makePayload()

        let firstOutcome = try await scheduler.schedule(payload)
        #expect(firstOutcome.path == .alarm)
        #expect(alarmManager.scheduledAlarmIDs.contains(payload.id))

        alarmManager.authorizationState = .denied
        let secondOutcome = try await scheduler.schedule(payload)
        #expect(secondOutcome.path == .notification)
        #expect(!alarmManager.scheduledAlarmIDs.contains(payload.id))
        let pending = await notificationCenter.pendingNotificationRequests()
        #expect(pending.count == 1)
    }

    @Test
    func cancelClearsBothPaths() async throws {
        let alarmManager = FakeAlarmManager(authorizationState: .authorized)
        let notificationCenter = FakeNotificationCenter()
        let scheduler = ReminderScheduler(
            alarmService: AlarmKitService(manager: alarmManager),
            notificationService: NotificationService(center: notificationCenter)
        )
        let payload = makePayload()

        try await scheduler.schedule(payload)
        await scheduler.cancel(for: payload.id)

        #expect(!alarmManager.scheduledAlarmIDs.contains(payload.id))
        let pending = await notificationCenter.pendingNotificationRequests()
        #expect(pending.isEmpty)
    }

    @Test
    func currentPathReflectsAlarmAuthorization() async {
        let alarmManager = FakeAlarmManager(authorizationState: .notDetermined)
        let scheduler = ReminderScheduler(
            alarmService: AlarmKitService(manager: alarmManager),
            notificationService: NotificationService(center: FakeNotificationCenter())
        )
        #expect(await scheduler.currentPath() == .notification)

        alarmManager.authorizationState = .authorized
        #expect(await scheduler.currentPath() == .alarm)
    }
}
