import SwiftData
import SwiftUI

// Phase 1 checkpoint scaffolding only — replaced by ReminderListView in Phase 4.
struct DebugReminderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.createdAt, order: .reverse) private var reminders: [Reminder]

    var body: some View {
        NavigationStack {
            List {
                ForEach(reminders) { reminder in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reminder.title)
                        Text(reminder.scheduleDescription())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: deleteReminders)
            }
            .navigationTitle("Debug Reminders")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Dummy", systemImage: "plus", action: addDummyReminder)
                }
            }
        }
    }

    private func addDummyReminder() {
        let reminder = Reminder(
            title: "Dummy Reminder \(reminders.count + 1)",
            spokenMessage: "This is a test reminder.",
            scheduledTime: .now.addingTimeInterval(3600)
        )
        modelContext.insert(reminder)
    }

    private func deleteReminders(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(reminders[index])
        }
    }
}

#Preview {
    DebugReminderListView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
