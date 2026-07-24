import SwiftData

enum CrierPlusSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Reminder.self] }
}

enum CrierPlusMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [CrierPlusSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
