import SwiftUI

struct RootView: View {
    var body: some View {
        DebugReminderListView()
    }
}

#Preview {
    RootView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
