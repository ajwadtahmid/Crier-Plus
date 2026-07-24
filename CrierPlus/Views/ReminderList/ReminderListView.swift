import SwiftData
import SwiftUI

struct ReminderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.scheduledTime) private var reminders: [Reminder]

    var body: some View {
        NavigationStack {
            Group {
                if reminders.isEmpty {
                    ContentUnavailableView(
                        "No Reminders Yet",
                        systemImage: "bell.badge",
                        description: Text("Add a reminder and I'll say it out loud when it's time.")
                    )
                } else {
                    List {
                        ForEach(reminders) { reminder in
                            ReminderRow(reminder: reminder)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.appBackground)
                                .listRowInsets(
                                    EdgeInsets(
                                        top: Theme.Spacing.xs,
                                        leading: Theme.Spacing.lg,
                                        bottom: Theme.Spacing.xs,
                                        trailing: Theme.Spacing.lg
                                    )
                                )
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground)
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                // Temporary until Phase 5 adds the real create/edit form.
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Sample", systemImage: "plus") { addSampleReminder(at: reminders.count) }
                }
            }
        }
    }

    private static let samples: [(String, RepeatPattern, [Int])] = [
        ("Take a walk", .none, []),
        ("Drink water", .daily, []),
        ("Team standup", .weekdays, []),
        ("Water the plants", .custom, [2, 5]),
    ]

    private func addSampleReminder(at index: Int) {
        let (title, pattern, days) = Self.samples[index % Self.samples.count]
        let reminder = Reminder(
            title: title,
            spokenMessage: "It's time to \(title.lowercased()).",
            scheduledTime: .now.addingTimeInterval(Double(index + 1) * 1800),
            repeatPattern: pattern,
            repeatDays: days
        )
        modelContext.insert(reminder)
    }
}

#Preview("Empty") {
    ReminderListView()
        .modelContainer(for: Reminder.self, inMemory: true)
}

#Preview("One reminder") {
    let container = try! ModelContainer(
        for: Reminder.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(
        Reminder(title: "Take a walk", spokenMessage: "Time to take a walk!", scheduledTime: .now)
    )
    return ReminderListView()
        .modelContainer(container)
}

#Preview("Many reminders") {
    let container = try! ModelContainer(
        for: Reminder.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let samples: [(String, RepeatPattern, [Int])] = [
        ("Take a walk", .none, []),
        ("Drink water", .daily, []),
        ("Team standup", .weekdays, []),
        ("Water the plants", .custom, [2, 5]),
        ("Weekly review", .weekly, []),
    ]
    for (index, sample) in samples.enumerated() {
        let reminder = Reminder(
            title: sample.0,
            spokenMessage: "It's time to \(sample.0.lowercased()).",
            scheduledTime: .now.addingTimeInterval(Double(index) * 1800),
            repeatPattern: sample.1,
            repeatDays: sample.2,
            isActive: index % 2 == 0
        )
        container.mainContext.insert(reminder)
    }
    return ReminderListView()
        .modelContainer(container)
}
