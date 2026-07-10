import SwiftData
import SwiftUI

@main
struct CrierPlusApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema([])
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
