import Foundation
import Testing
import UserNotifications

@testable import CrierPlus

struct NotificationServiceTests {
    private func makePayload(
        id: UUID = UUID(),
        pattern: RepeatPattern,
        days: [Int] = [],
        scheduledTime: Date = .now.addingTimeInterval(3600),
        audioFilePath: String? = nil
    ) -> ReminderSchedulingPayload {
        ReminderSchedulingPayload(
            id: id,
            title: "Test Reminder",
            spokenMessage: "This is a test.",
            scheduledTime: scheduledTime,
            repeatPattern: pattern,
            repeatDays: days,
            audioFilePath: audioFilePath
        )
    }

    @Test
    func schedulingOneShotProducesASingleRequest() async throws {
        let service = NotificationService(center: FakeNotificationCenter())
        let payload = makePayload(pattern: .none)

        let result = try await service.schedule(payload)
        #expect(result.requestIdentifiers.count == 1)
    }

    @Test
    func schedulingWeekdaysProducesFiveRequests() async throws {
        let service = NotificationService(center: FakeNotificationCenter())
        let payload = makePayload(pattern: .weekdays)

        let result = try await service.schedule(payload)
        #expect(result.requestIdentifiers.count == 5)
    }

    @Test
    func schedulingCustomProducesOnePerSelectedDay() async throws {
        let service = NotificationService(center: FakeNotificationCenter())
        let payload = makePayload(pattern: .custom, days: [2, 4, 6])

        let result = try await service.schedule(payload)
        #expect(result.requestIdentifiers.count == 3)
    }

    @Test
    func cancelRemovesAllPendingRequestsForTheReminder() async throws {
        let service = NotificationService(center: FakeNotificationCenter())
        let payload = makePayload(pattern: .weekly)

        _ = try await service.schedule(payload)
        let scheduledIdentifiers = await service.pendingIdentifiers(for: payload.id)
        #expect(!scheduledIdentifiers.isEmpty)

        await service.cancel(for: payload.id)
        let remainingIdentifiers = await service.pendingIdentifiers(for: payload.id)
        #expect(remainingIdentifiers.isEmpty)
    }

    @Test
    func reschedulingReplacesRatherThanDuplicatingRequests() async throws {
        let service = NotificationService(center: FakeNotificationCenter())
        let reminderID = UUID()
        let weekdaysPayload = makePayload(id: reminderID, pattern: .weekdays)

        _ = try await service.schedule(weekdaysPayload)
        #expect(await service.pendingIdentifiers(for: reminderID).count == 5)

        let dailyPayload = makePayload(id: reminderID, pattern: .daily)
        let result = try await service.schedule(dailyPayload)
        #expect(result.requestIdentifiers.count == 1)
        #expect(await service.pendingIdentifiers(for: reminderID).count == 1)
    }

    @Test
    func schedulingInstallsTheGeneratedAudioAsACustomSound() async throws {
        let audioService = AudioGenerationService()
        let notificationService = NotificationService(center: FakeNotificationCenter())
        let reminderID = UUID()

        let fileURL = try await audioService.generateAudio(for: reminderID, message: "This is a test.")
        let payload = makePayload(id: reminderID, pattern: .none, audioFilePath: fileURL.lastPathComponent)

        let result = try await notificationService.schedule(payload)
        #expect(result.soundWarning == nil)

        let soundsDirectory = try FileManager.default.url(
            for: .libraryDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Sounds", isDirectory: true)
        let installedURL = soundsDirectory.appendingPathComponent(fileURL.lastPathComponent)
        #expect(FileManager.default.fileExists(atPath: installedURL.path))
    }

    @Test
    func schedulingWarnsAndFallsBackWhenAudioExceedsTheCustomSoundLimit() async throws {
        let audioService = AudioGenerationService()
        let notificationService = NotificationService(center: FakeNotificationCenter())
        let reminderID = UUID()

        let longMessage = String(
            repeating: "This is a very long reminder message meant to exceed the custom sound duration limit. ",
            count: 30
        )
        let fileURL = try await audioService.generateAudio(for: reminderID, message: longMessage)
        let payload = makePayload(id: reminderID, pattern: .none, audioFilePath: fileURL.lastPathComponent)

        let result = try await notificationService.schedule(payload)
        guard case .fallbackTooLong(let duration) = result.soundWarning else {
            Issue.record("Expected a fallbackTooLong warning, got \(String(describing: result.soundWarning))")
            return
        }
        #expect(duration > CustomSoundResolver.maximumDuration)
    }

    @Test
    func categoryIsRegisteredWithSnoozeAndDismissActions() async throws {
        NotificationService.registerCategories()
        let categories = await UNUserNotificationCenter.current().notificationCategories()
        let reminderCategory = categories.first { $0.identifier == NotificationService.categoryIdentifier }

        #expect(reminderCategory != nil)
        let actionIdentifiers = Set(reminderCategory?.actions.map(\.identifier) ?? [])
        #expect(
            actionIdentifiers == [NotificationService.snoozeActionIdentifier, NotificationService.dismissActionIdentifier]
        )
    }
}
