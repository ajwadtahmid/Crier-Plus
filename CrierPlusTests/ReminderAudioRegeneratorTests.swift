import Foundation
import SwiftData
import Testing

@testable import CrierPlus

/// `UserDefaults` isn't declared `Sendable` in the shipped SDK (it's Objective-C-bridged, not
/// pure Swift), which makes Swift 6's region-based "sending" analysis flag passing one instance
/// into both the `AudioGenerationService` actor and the `@MainActor` `ReminderAudioRegenerator`
/// in these tests — even though `UserDefaults` is documented as thread-safe. Same pattern as
/// `AlarmKitService`'s treatment of `AlarmManager`.
extension UserDefaults: @retroactive @unchecked Sendable {}

@MainActor
struct ReminderAudioRegeneratorTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: CrierPlusSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: schema,
            migrationPlan: CrierPlusMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// Returns two independent `UserDefaults` instances backed by the same suite — i.e. the same
    /// underlying storage — rather than one shared instance, since passing one `UserDefaults`
    /// value into both the actor-isolated `AudioGenerationService` and the `@MainActor`
    /// `ReminderAudioRegenerator` trips Swift 6's region-based "sending" analysis even though
    /// `UserDefaults` is safe to share.
    private func makeUserDefaultsPair() -> (audio: UserDefaults, regenerator: UserDefaults) {
        let suiteName = "ReminderAudioRegeneratorTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, UserDefaults(suiteName: suiteName)!)
    }

    /// A `ReminderScheduler` backed by fakes, plus the fake notification center to inspect —
    /// reminders default to `isActive: true`, and `regenerateAll` now reschedules active
    /// reminders, so every test needs this rather than hitting the real system services.
    private func makeScheduler() -> (scheduler: ReminderScheduler, notificationCenter: FakeNotificationCenter) {
        let notificationCenter = FakeNotificationCenter()
        let scheduler = ReminderScheduler(
            alarmService: AlarmKitService(manager: FakeAlarmManager(authorizationState: .denied)),
            notificationService: NotificationService(center: notificationCenter)
        )
        return (scheduler, notificationCenter)
    }

    @Test
    func regenerateAllRendersAudioForEveryReminder() async throws {
        let container = try makeContainer()
        let reminders = [
            Reminder(title: "Take a walk", spokenMessage: "Time to take a walk!", scheduledTime: .now),
            Reminder(title: "Drink water", spokenMessage: "Stay hydrated!", scheduledTime: .now),
        ]
        reminders.forEach { container.mainContext.insert($0) }
        try container.mainContext.save()
        defer { for reminder in reminders { try? FileManager.default.removeItem(at: try! AudioGenerationService.audioFileURL(for: reminder.id)) } }

        let userDefaults = makeUserDefaultsPair()
        let audioService = AudioGenerationService(userDefaults: userDefaults.audio)
        let regenerator = ReminderAudioRegenerator(
            audioService: audioService,
            scheduler: makeScheduler().scheduler,
            userDefaults: userDefaults.regenerator
        )
        await regenerator.regenerateAll(reminders)

        for reminder in reminders {
            #expect(reminder.audioFilePath != nil)
            let url = try AudioGenerationService.audioFileURL(for: reminder.id)
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test
    func regenerateAllReplacesAPreviouslyRenderedFile() async throws {
        let container = try makeContainer()
        let reminder = Reminder(title: "Take a walk", spokenMessage: "Time to take a walk!", scheduledTime: .now)
        container.mainContext.insert(reminder)
        try container.mainContext.save()
        defer { try? FileManager.default.removeItem(at: try! AudioGenerationService.audioFileURL(for: reminder.id)) }

        let userDefaults = makeUserDefaultsPair()
        let audioService = AudioGenerationService(userDefaults: userDefaults.audio)
        let regenerator = ReminderAudioRegenerator(
            audioService: audioService,
            scheduler: makeScheduler().scheduler,
            userDefaults: userDefaults.regenerator
        )

        await regenerator.regenerateAll([reminder])
        let firstModified =
            try FileManager.default.attributesOfItem(atPath: AudioGenerationService.audioFileURL(for: reminder.id).path)[
                .modificationDate
            ] as? Date ?? .distantPast

        try await Task.sleep(nanoseconds: 1_000_000_000)

        await regenerator.regenerateAll([reminder])
        let secondModified =
            try FileManager.default.attributesOfItem(atPath: AudioGenerationService.audioFileURL(for: reminder.id).path)[
                .modificationDate
            ] as? Date ?? .distantPast

        #expect(secondModified > firstModified)
    }

    @Test
    func regenerateAllStampsTheCurrentVoiceIdentifierOntoEveryReminder() async throws {
        let container = try makeContainer()
        let reminder = Reminder(title: "Take a walk", spokenMessage: "Time to take a walk!", scheduledTime: .now)
        container.mainContext.insert(reminder)
        try container.mainContext.save()
        defer { try? FileManager.default.removeItem(at: try! AudioGenerationService.audioFileURL(for: reminder.id)) }

        let userDefaults = makeUserDefaultsPair()
        userDefaults.audio.set("com.apple.voice.test-identifier", forKey: AppStorageKeys.voiceIdentifier)
        let audioService = AudioGenerationService(userDefaults: userDefaults.audio)
        let regenerator = ReminderAudioRegenerator(
            audioService: audioService,
            scheduler: makeScheduler().scheduler,
            userDefaults: userDefaults.regenerator
        )

        await regenerator.regenerateAll([reminder])

        #expect(reminder.voiceIdentifier == "com.apple.voice.test-identifier")
    }

    @Test
    func regenerateAllReschedulesAnActiveReminderSoTheNewSoundTakesEffect() async throws {
        let container = try makeContainer()
        let reminder = Reminder(
            title: "Take a walk",
            spokenMessage: "Time to take a walk!",
            scheduledTime: .now.addingTimeInterval(3600),
            isActive: true
        )
        container.mainContext.insert(reminder)
        try container.mainContext.save()
        defer { try? FileManager.default.removeItem(at: try! AudioGenerationService.audioFileURL(for: reminder.id)) }

        let userDefaults = makeUserDefaultsPair()
        let audioService = AudioGenerationService(userDefaults: userDefaults.audio)
        let (scheduler, notificationCenter) = makeScheduler()
        let regenerator = ReminderAudioRegenerator(
            audioService: audioService,
            scheduler: scheduler,
            userDefaults: userDefaults.regenerator
        )

        await regenerator.regenerateAll([reminder])

        let pending = await notificationCenter.pendingNotificationRequests()
        #expect(!pending.isEmpty)
    }

    @Test
    func regenerateAllDoesNotScheduleAnInactiveReminder() async throws {
        let container = try makeContainer()
        let reminder = Reminder(
            title: "Take a walk",
            spokenMessage: "Time to take a walk!",
            scheduledTime: .now.addingTimeInterval(3600),
            isActive: false
        )
        container.mainContext.insert(reminder)
        try container.mainContext.save()
        defer { try? FileManager.default.removeItem(at: try! AudioGenerationService.audioFileURL(for: reminder.id)) }

        let userDefaults = makeUserDefaultsPair()
        let audioService = AudioGenerationService(userDefaults: userDefaults.audio)
        let (scheduler, notificationCenter) = makeScheduler()
        let regenerator = ReminderAudioRegenerator(
            audioService: audioService,
            scheduler: scheduler,
            userDefaults: userDefaults.regenerator
        )

        await regenerator.regenerateAll([reminder])

        let pending = await notificationCenter.pendingNotificationRequests()
        #expect(pending.isEmpty)
    }
}
