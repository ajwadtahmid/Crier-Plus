import AlarmKit
import Foundation
import Testing

@testable import CrierPlus

struct AlarmScheduleMappingTests {
    private let calendar = Calendar(identifier: .gregorian)

    /// 2026-07-24 is a Friday.
    private func scheduledTime(hour: Int = 8, minute: Int = 30) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 24, hour: hour, minute: minute))!
    }

    @Test
    func oneShotProducesAFixedSchedule() {
        let schedule = AlarmKitService.schedule(
            repeatPattern: .none,
            repeatDays: [],
            scheduledTime: scheduledTime(),
            calendar: calendar
        )
        #expect(schedule == .fixed(scheduledTime()))
    }

    @Test
    func dailyRepeatsOnAllSevenWeekdays() {
        let schedule = AlarmKitService.schedule(
            repeatPattern: .daily,
            repeatDays: [],
            scheduledTime: scheduledTime(),
            calendar: calendar
        )
        guard case .relative(let relative) = schedule else {
            Issue.record("Expected a relative schedule, got \(schedule)")
            return
        }
        #expect(relative.time.hour == 8)
        #expect(relative.time.minute == 30)
        guard case .weekly(let days) = relative.repeats else {
            Issue.record("Expected weekly recurrence, got \(relative.repeats)")
            return
        }
        #expect(
            Set(days) == [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        )
    }

    @Test
    func weekdaysRepeatsMondayThroughFriday() {
        let schedule = AlarmKitService.schedule(
            repeatPattern: .weekdays,
            repeatDays: [],
            scheduledTime: scheduledTime(),
            calendar: calendar
        )
        guard case .relative(let relative) = schedule, case .weekly(let days) = relative.repeats else {
            Issue.record("Expected a weekly relative schedule, got \(schedule)")
            return
        }
        #expect(Set(days) == [.monday, .tuesday, .wednesday, .thursday, .friday])
    }

    @Test
    func weeklyRepeatsOnTheScheduledWeekday() {
        // 2026-07-24 is a Friday.
        let schedule = AlarmKitService.schedule(
            repeatPattern: .weekly,
            repeatDays: [],
            scheduledTime: scheduledTime(),
            calendar: calendar
        )
        guard case .relative(let relative) = schedule, case .weekly(let days) = relative.repeats else {
            Issue.record("Expected a weekly relative schedule, got \(schedule)")
            return
        }
        #expect(days == [.friday])
    }

    @Test
    func customRepeatsOnlyOnSelectedDays() {
        let schedule = AlarmKitService.schedule(
            repeatPattern: .custom,
            repeatDays: [2, 5, 7],
            scheduledTime: scheduledTime(),
            calendar: calendar
        )
        guard case .relative(let relative) = schedule, case .weekly(let days) = relative.repeats else {
            Issue.record("Expected a weekly relative schedule, got \(schedule)")
            return
        }
        #expect(Set(days) == [.monday, .thursday, .saturday])
    }
}

struct AlarmKitServiceTests {
    private func makePayload(
        id: UUID = UUID(),
        pattern: RepeatPattern = .none,
        days: [Int] = [],
        scheduledTime: Date = .now.addingTimeInterval(3600)
    ) -> ReminderSchedulingPayload {
        ReminderSchedulingPayload(
            id: id,
            title: "Test Reminder",
            spokenMessage: "This is a test.",
            scheduledTime: scheduledTime,
            repeatPattern: pattern,
            repeatDays: days,
            audioFilePath: nil
        )
    }

    @Test
    func schedulingWhenAuthorizedCreatesAnAlarm() async throws {
        let manager = FakeAlarmManager(authorizationState: .authorized)
        let service = AlarmKitService(manager: manager)
        let payload = makePayload()

        try await service.schedule(payload)
        #expect(manager.scheduledAlarmIDs.contains(payload.id))
    }

    @Test
    func cancelRemovesTheAlarm() async throws {
        let manager = FakeAlarmManager(authorizationState: .authorized)
        let service = AlarmKitService(manager: manager)
        let payload = makePayload()

        try await service.schedule(payload)
        try await service.cancel(for: payload.id)
        #expect(!manager.scheduledAlarmIDs.contains(payload.id))
        #expect(manager.cancelledAlarmIDs == [payload.id])
    }

    @Test
    func authorizationStateReflectsTheUnderlyingManager() async {
        let manager = FakeAlarmManager(authorizationState: .denied)
        let service = AlarmKitService(manager: manager)
        #expect(await service.authorizationState == .denied)
    }

    @Test
    func schedulingInstallsTheGeneratedAudioAsTheAlarmSound() async throws {
        let audioService = AudioGenerationService()
        let manager = FakeAlarmManager(authorizationState: .authorized)
        let service = AlarmKitService(manager: manager)
        let reminderID = UUID()

        let fileURL = try await audioService.generateAudio(for: reminderID, message: "This is a test.")
        let payload = makePayload(id: reminderID, pattern: .none)
        let payloadWithAudio = ReminderSchedulingPayload(
            id: payload.id,
            title: payload.title,
            spokenMessage: payload.spokenMessage,
            scheduledTime: payload.scheduledTime,
            repeatPattern: payload.repeatPattern,
            repeatDays: payload.repeatDays,
            audioFilePath: fileURL.lastPathComponent
        )

        let warning = try await service.schedule(payloadWithAudio)
        #expect(warning == nil)
        #expect(manager.scheduledAlarmIDs.contains(reminderID))
    }

    @Test
    func schedulingWarnsWhenAudioExceedsTheCustomSoundLimit() async throws {
        let audioService = AudioGenerationService()
        let manager = FakeAlarmManager(authorizationState: .authorized)
        let service = AlarmKitService(manager: manager)
        let reminderID = UUID()

        let longMessage = String(
            repeating: "This is a very long reminder message meant to exceed the custom sound duration limit. ",
            count: 30
        )
        let fileURL = try await audioService.generateAudio(for: reminderID, message: longMessage)
        let payload = makePayload(id: reminderID, pattern: .none)
        let payloadWithAudio = ReminderSchedulingPayload(
            id: payload.id,
            title: payload.title,
            spokenMessage: payload.spokenMessage,
            scheduledTime: payload.scheduledTime,
            repeatPattern: payload.repeatPattern,
            repeatDays: payload.repeatDays,
            audioFilePath: fileURL.lastPathComponent
        )

        let warning = try await service.schedule(payloadWithAudio)
        guard case .fallbackTooLong(let duration) = warning else {
            Issue.record("Expected a fallbackTooLong warning, got \(String(describing: warning))")
            return
        }
        #expect(duration > CustomSoundResolver.maximumDuration)
    }
}
