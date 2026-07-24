import Foundation
import Testing

@testable import CrierPlus

struct RepeatPatternTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test
    func dailyDescription() {
        let description = RepeatPattern.daily.scheduleDescription(scheduledTime: .now, calendar: calendar)
        #expect(description == "Every day")
    }

    @Test
    func weekdaysDescription() {
        let description = RepeatPattern.weekdays.scheduleDescription(scheduledTime: .now, calendar: calendar)
        #expect(description == "Weekdays")
    }

    @Test
    func weeklyDescription() {
        let description = RepeatPattern.weekly.scheduleDescription(scheduledTime: .now, calendar: calendar)
        #expect(description == "Weekly")
    }

    @Test
    func customDescriptionListsSelectedDaysInWeekOrder() {
        // 6 = Friday, 2 = Monday, 4 = Wednesday (1-based, Sunday = 1)
        let description = RepeatPattern.custom.scheduleDescription(
            repeatDays: [6, 2, 4],
            scheduledTime: .now,
            calendar: calendar
        )
        #expect(description == "Mon, Wed, Fri")
    }

    @Test
    func customDescriptionWithNoDaysSelectedFallsBackToLabel() {
        let description = RepeatPattern.custom.scheduleDescription(
            repeatDays: [],
            scheduledTime: .now,
            calendar: calendar
        )
        #expect(description == "Custom")
    }

    @Test
    func oneTimeUpcomingDescriptionShowsDateOnly() {
        let scheduledTime = date(year: 2026, month: 7, day: 15)
        let now = date(year: 2026, month: 7, day: 10)
        let description = RepeatPattern.none.scheduleDescription(
            scheduledTime: scheduledTime,
            now: now,
            calendar: calendar
        )
        #expect(description == "Jul 15")
    }

    @Test
    func oneTimeExpiredDescriptionShowsExpiredPrefix() {
        let scheduledTime = date(year: 2026, month: 7, day: 3)
        let now = date(year: 2026, month: 7, day: 10)
        let description = RepeatPattern.none.scheduleDescription(
            scheduledTime: scheduledTime,
            now: now,
            calendar: calendar
        )
        #expect(description == "Expired · Jul 3")
    }
}
