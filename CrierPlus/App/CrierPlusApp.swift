import SwiftData
import SwiftUI
import UserNotifications

@main
struct CrierPlusApp: App {
    let modelContainer: ModelContainer = try! CrierPlusModelContainer.make()

    init() {
        NotificationService.registerCategories()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
