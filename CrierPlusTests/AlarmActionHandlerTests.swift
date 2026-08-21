import Foundation
import SwiftData
import Testing
import UserNotifications

@testable import CrierPlus

@MainActor
struct AlarmActionHandlerTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: CrierPlusSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: schema,
            migrationPlan: CrierPlusMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private func makeHandler(
        container: ModelContainer,
        alarmManager: FakeAlarmManager = FakeAlarmManager(),
        notificationCenter: FakeNotificationCenter = FakeNotificationCenter()
    ) -> AlarmActionHandler {
        AlarmActionHandler(
            alarmService: AlarmKitService(manager: alarmManager),
            notificationService: NotificationService(center: notificationCenter),
            makeModelContainer: { container }
        )
    }

    @Test
    func dismissDeactivatesAOneTimeReminder() async throws {
        let container = try makeContainer()
        let reminder = Reminder(
            title: "Take a walk",
            spokenMessage: "Time to take a walk!",
            scheduledTime: .now,
            repeatPattern: .none
        )
        container.mainContext.insert(reminder)
        try container.mainContext.save()

        let handler = makeHandler(container: container)
        try await handler.dismiss(reminderID: reminder.id, path: .notification)

        #expect(try fetchIsActive(reminder.id, in: container) == false)
    }

    @Test
    func dismissLeavesARepeatingReminderActive() async throws {
        let container = try makeContainer()
        let reminder = Reminder(
            title: "Drink water",
            spokenMessage: "Stay hydrated!",
            scheduledTime: .now,
            repeatPattern: .daily
        )
        container.mainContext.insert(reminder)
        try container.mainContext.save()

        let handler = makeHandler(container: container)
        try await handler.dismiss(reminderID: reminder.id, path: .notification)

        #expect(try fetchIsActive(reminder.id, in: container) == true)
    }

    /// `AlarmActionHandler` mutates through its own fresh `ModelContext`, so a save there isn't
    /// visible on an object already registered in a different context (like `container.mainContext`
    /// after the initial insert) without independently re-fetching.
    private func fetchIsActive(_ id: UUID, in container: ModelContainer) throws -> Bool? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Reminder>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.isActive
    }

    @Test
    func dismissOnTheAlarmPathAlsoStopsTheSystemAlarm() async throws {
        let container = try makeContainer()
        let reminder = Reminder(
            title: "Take a walk",
            spokenMessage: "Time to take a walk!",
            scheduledTime: .now,
            repeatPattern: .none
        )
        container.mainContext.insert(reminder)
        try container.mainContext.save()

        let alarmManager = FakeAlarmManager()
        let handler = makeHandler(container: container, alarmManager: alarmManager)
        try await handler.dismiss(reminderID: reminder.id, path: .alarm)

        #expect(alarmManager.stoppedAlarmIDs == [reminder.id])
    }

    @Test
    func snoozeOnTheNotificationPathSchedulesASingleCorrectlyTimedFollowUpReusingTheSoundFile() async throws {
        let container = try makeContainer()
        let audioService = AudioGenerationService()
        let fileURL = try await audioService.generateAudio(for: UUID(), message: "This is a test.")
        let reminder = Reminder(
            title: "Take a walk",
            spokenMessage: "Time to take a walk!",
            scheduledTime: .now,
            audioFilePath: fileURL.lastPathComponent
        )
        container.mainContext.insert(reminder)
        try container.mainContext.save()

        let notificationCenter = FakeNotificationCenter()
        let handler = makeHandler(container: container, notificationCenter: notificationCenter)
        try await handler.snooze(reminderID: reminder.id, path: .notification)

        let pending = await notificationCenter.pendingNotificationRequests()
        #expect(pending.count == 1)
        guard let request = pending.first, let trigger = request.trigger as? UNTimeIntervalNotificationTrigger else {
            Issue.record("Expected a single time-interval trigger")
            return
        }
        #expect(trigger.timeInterval == AlarmActionHandler.snoozeDuration)
        #expect(request.identifier == "\(reminder.id.uuidString)-snooze")
        #expect(request.content.sound != nil)
    }

    @Test
    func snoozeOnTheAlarmPathStartsTheSystemCountdownInsteadOfReschedulingANotification() async throws {
        let container = try makeContainer()
        let reminder = Reminder(
            title: "Take a walk",
            spokenMessage: "Time to take a walk!",
            scheduledTime: .now
        )
        container.mainContext.insert(reminder)
        try container.mainContext.save()

        let alarmManager = FakeAlarmManager()
        let notificationCenter = FakeNotificationCenter()
        let handler = makeHandler(container: container, alarmManager: alarmManager, notificationCenter: notificationCenter)
        try await handler.snooze(reminderID: reminder.id, path: .alarm)

        #expect(alarmManager.countdownAlarmIDs == [reminder.id])
        let pending = await notificationCenter.pendingNotificationRequests()
        #expect(pending.isEmpty)
    }
}
