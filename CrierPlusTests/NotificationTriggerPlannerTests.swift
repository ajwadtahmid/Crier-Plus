import Foundation
import Testing

@testable import CrierPlus

struct NotificationTriggerPlannerTests {
    private let calendar = Calendar(identifier: .gregorian)

    /// 2026-07-24 is a Friday.
    private func scheduledTime(hour: Int = 8, minute: Int = 30) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 24, hour: hour, minute: minute))!
    }

    @Test
    func oneShotProducesASingleNonRepeatingPlanWithFullDate() {
        let plans = NotificationTriggerPlanner.plans(
            repeatPattern: .none,
            repeatDays: [],
            scheduledTime: scheduledTime(),
            calendar: calendar
        )
        #expect(plans.count == 1)
        #expect(plans[0].repeats == false)
        #expect(plans[0].dateComponents.year == 2026)
        #expect(plans[0].dateComponents.month == 7)
        #expect(plans[0].dateComponents.day == 24)
        #expect(plans[0].dateComponents.hour == 8)
        #expect(plans[0].dateComponents.minute == 30)
    }

    @Test
    func dailyProducesASingleRepeatingPlanWithOnlyTimeOfDay() {
        let plans = NotificationTriggerPlanner.plans(
            repeatPattern: .daily,
            repeatDays: [],
            scheduledTime: scheduledTime(),
            calendar: calendar
        )
        #expect(plans.count == 1)
        #expect(plans[0].repeats == true)
        #expect(plans[0].dateComponents.hour == 8)
        #expect(plans[0].dateComponents.minute == 30)
        #expect(plans[0].dateComponents.day == nil)
        #expect(plans[0].dateComponents.weekday == nil)
    }

    @Test
    func weekdaysProducesFiveRepeatingPlansOneForEachWeekday() {
        let plans = NotificationTriggerPlanner.plans(
            repeatPattern: .weekdays,
            repeatDays: [],
            scheduledTime: scheduledTime(),
            calendar: calendar
        )
        #expect(plans.count == 5)
        #expect(Set(plans.map { $0.dateComponents.weekday }) == Set(2...6))
        #expect(plans.allSatisfy { $0.repeats == true })
        #expect(plans.allSatisfy { $0.dateComponents.hour == 8 && $0.dateComponents.minute == 30 })
    }

    @Test
    func weeklyProducesASingleRepeatingPlanOnTheScheduledWeekday() {
        // 2026-07-24 is a Friday, weekday 6.
        let plans = NotificationTriggerPlanner.plans(
            repeatPattern: .weekly,
            repeatDays: [],
            scheduledTime: scheduledTime(),
            calendar: calendar
        )
        #expect(plans.count == 1)
        #expect(plans[0].repeats == true)
        #expect(plans[0].dateComponents.weekday == 6)
    }

    @Test
    func customProducesOnePlanPerSelectedDaySortedAscending() {
        let plans = NotificationTriggerPlanner.plans(
            repeatPattern: .custom,
            repeatDays: [5, 2, 7],
            scheduledTime: scheduledTime(),
            calendar: calendar
        )
        #expect(plans.count == 3)
        #expect(plans.map(\.dateComponents.weekday) == [2, 5, 7])
        #expect(plans.allSatisfy { $0.repeats == true })
    }

    @Test
    func customWithNoDaysProducesNoPlans() {
        let plans = NotificationTriggerPlanner.plans(
            repeatPattern: .custom,
            repeatDays: [],
            scheduledTime: scheduledTime(),
            calendar: calendar
        )
        #expect(plans.isEmpty)
    }

    @Test
    func identifierSuffixesAreUniqueWithinAPlanSet() {
        let plans = NotificationTriggerPlanner.plans(
            repeatPattern: .weekdays,
            repeatDays: [],
            scheduledTime: scheduledTime(),
            calendar: calendar
        )
        #expect(Set(plans.map(\.identifierSuffix)).count == plans.count)
    }
}
