import Foundation
import SwiftData
import Testing

@testable import CrierPlus

@MainActor
struct ReminderModelTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: CrierPlusSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: schema,
            migrationPlan: CrierPlusMigrationPlan.self,
            configurations: [configuration]
        )
    }

    @Test
    func insertAndFetchReminder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let reminder = Reminder(title: "Take a walk", spokenMessage: "Time to take a walk!", scheduledTime: .now)
        context.insert(reminder)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Reminder>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "Take a walk")
    }

    @Test
    func deleteReminder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let reminder = Reminder(title: "Drink water", spokenMessage: "Stay hydrated!", scheduledTime: .now)
        context.insert(reminder)
        try context.save()

        context.delete(reminder)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Reminder>())
        #expect(fetched.isEmpty)
    }

    @Test
    func togglingIsActivePersists() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let reminder = Reminder(title: "Toggle Test", spokenMessage: "msg", scheduledTime: .now)
        context.insert(reminder)
        try context.save()

        reminder.isActive = false
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Reminder>())
        #expect(fetched.first?.isActive == false)
    }

    @Test
    func defaultsApplyOnInit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let scheduledTime = Date.now.addingTimeInterval(60)
        let reminder = Reminder(title: "Stretch", spokenMessage: "Stretch it out.", scheduledTime: scheduledTime)
        context.insert(reminder)
        try context.save()

        #expect(reminder.repeatPattern == .none)
        #expect(reminder.repeatDays.isEmpty)
        #expect(reminder.isActive == true)
        #expect(reminder.audioFilePath == nil)
        #expect(reminder.voiceIdentifier == nil)
    }
}
