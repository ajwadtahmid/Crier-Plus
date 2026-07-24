import SwiftData
import Testing

@testable import CrierPlus

@MainActor
struct SchemaMigrationPlanTests {
    @Test
    func containerInitializesThroughMigrationPlanWithNoStagesYet() throws {
        let schema = Schema(versionedSchema: CrierPlusSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: CrierPlusMigrationPlan.self,
            configurations: [configuration]
        )

        let reminder = Reminder(title: "Migration check", spokenMessage: "Still here.", scheduledTime: .now)
        container.mainContext.insert(reminder)
        try container.mainContext.save()

        let fetched = try container.mainContext.fetch(FetchDescriptor<Reminder>())
        #expect(fetched.count == 1)
    }
}
