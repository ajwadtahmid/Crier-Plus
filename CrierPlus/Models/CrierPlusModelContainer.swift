import SwiftData

/// Shared factory for the app's persistent `ModelContainer`, so anything that needs to touch
/// SwiftData outside the normal view hierarchy — an `AppIntent` responding to a Live Activity
/// button while the app isn't running, for instance — opens the same on-disk store rather than
/// duplicating this setup.
enum CrierPlusModelContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema(versionedSchema: CrierPlusSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema)
        return try ModelContainer(
            for: schema,
            migrationPlan: CrierPlusMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
