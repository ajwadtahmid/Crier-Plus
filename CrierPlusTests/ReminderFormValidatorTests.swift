import Foundation
import Testing

@testable import CrierPlus

struct ReminderFormValidatorTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(hour: Int, minute: Int, second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 24, hour: hour, minute: minute, second: second))!
    }

    private var now: Date { date(hour: 11, minute: 5, second: 30) }
    private var farFuture: Date { date(hour: 12, minute: 0) }

    @Test
    func validInputProducesNoErrors() {
        let errors = ReminderFormValidator.validate(
            title: "Take a walk",
            message: "Time to take a walk!",
            scheduledTime: farFuture,
            repeatPattern: .none,
            repeatDays: [],
            now: now,
            calendar: calendar
        )
        #expect(errors.isEmpty)
    }

    @Test
    func emptyTitleFailsValidation() {
        let errors = ReminderFormValidator.validate(
            title: "",
            message: "msg",
            scheduledTime: farFuture,
            repeatPattern: .none,
            repeatDays: [],
            now: now,
            calendar: calendar
        )
        #expect(errors == [.titleRequired])
    }

    @Test
    func whitespaceOnlyTitleFailsValidation() {
        let errors = ReminderFormValidator.validate(
            title: "   \n  ",
            message: "msg",
            scheduledTime: farFuture,
            repeatPattern: .none,
            repeatDays: [],
            now: now,
            calendar: calendar
        )
        #expect(errors == [.titleRequired])
    }

    @Test
    func messageOverLimitFailsValidation() {
        let longMessage = String(repeating: "a", count: ReminderFormValidator.messageCharacterLimit + 1)
        let errors = ReminderFormValidator.validate(
            title: "Title",
            message: longMessage,
            scheduledTime: farFuture,
            repeatPattern: .none,
            repeatDays: [],
            now: now,
            calendar: calendar
        )
        #expect(errors == [.messageTooLong])
    }

    @Test
    func messageAtExactLimitPasses() {
        let exactMessage = String(repeating: "a", count: ReminderFormValidator.messageCharacterLimit)
        let errors = ReminderFormValidator.validate(
            title: "Title",
            message: exactMessage,
            scheduledTime: farFuture,
            repeatPattern: .none,
            repeatDays: [],
            now: now,
            calendar: calendar
        )
        #expect(errors.isEmpty)
    }

    @Test
    func customRepeatWithNoDaysFailsValidation() {
        let errors = ReminderFormValidator.validate(
            title: "Title",
            message: "msg",
            scheduledTime: farFuture,
            repeatPattern: .custom,
            repeatDays: [],
            now: now,
            calendar: calendar
        )
        #expect(errors == [.customRepeatRequiresADay])
    }

    @Test
    func customRepeatWithADaySelectedPasses() {
        let errors = ReminderFormValidator.validate(
            title: "Title",
            message: "msg",
            scheduledTime: farFuture,
            repeatPattern: .custom,
            repeatDays: [2],
            now: now,
            calendar: calendar
        )
        #expect(errors.isEmpty)
    }

    @Test
    func multipleFailuresAreAllReported() {
        let longMessage = String(repeating: "a", count: ReminderFormValidator.messageCharacterLimit + 1)
        let errors = ReminderFormValidator.validate(
            title: "",
            message: longMessage,
            scheduledTime: farFuture,
            repeatPattern: .custom,
            repeatDays: [],
            now: now,
            calendar: calendar
        )
        #expect(errors == [.titleRequired, .messageTooLong, .customRepeatRequiresADay])
    }

    @Test
    func oneTimeReminderInThePastMinuteFailsValidation() {
        let errors = ReminderFormValidator.validate(
            title: "Title",
            message: "msg",
            scheduledTime: date(hour: 11, minute: 4),
            repeatPattern: .none,
            repeatDays: [],
            now: now,
            calendar: calendar
        )
        #expect(errors == [.scheduledTimeMustBeInFuture])
    }

    @Test
    func oneTimeReminderInTheSameMinuteAsNowPasses() {
        // now is 11:05:30 — picking 11:05 (the current minute) should still be allowed,
        // matching how modern reminder apps treat "right now" as valid, not expired.
        let errors = ReminderFormValidator.validate(
            title: "Title",
            message: "msg",
            scheduledTime: date(hour: 11, minute: 5),
            repeatPattern: .none,
            repeatDays: [],
            now: now,
            calendar: calendar
        )
        #expect(errors.isEmpty)
    }

    @Test
    func oneTimeReminderInTheNextMinutePassesRegardlessOfCurrentSeconds() {
        // Reproduces the reported bug: now is 11:05:30, so 11:06 is a real future minute
        // and must not be rejected just because it's only thirty seconds away.
        let errors = ReminderFormValidator.validate(
            title: "Title",
            message: "msg",
            scheduledTime: date(hour: 11, minute: 6),
            repeatPattern: .none,
            repeatDays: [],
            now: now,
            calendar: calendar
        )
        #expect(errors.isEmpty)
    }

    @Test
    func repeatingReminderInThePastStillPasses() {
        let errors = ReminderFormValidator.validate(
            title: "Title",
            message: "msg",
            scheduledTime: date(hour: 9, minute: 0),
            repeatPattern: .daily,
            repeatDays: [],
            now: now,
            calendar: calendar
        )
        #expect(errors.isEmpty)
    }
}
