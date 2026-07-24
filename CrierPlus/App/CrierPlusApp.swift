import SwiftData
import SwiftUI

@main
struct CrierPlusApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: CrierPlusSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(
            for: schema,
            migrationPlan: CrierPlusMigrationPlan.self,
            configurations: [configuration]
        )
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
