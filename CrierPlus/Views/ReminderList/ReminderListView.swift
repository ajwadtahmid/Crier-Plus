import SwiftData
import SwiftUI

struct ReminderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.scheduledTime) private var reminders: [Reminder]

    @State private var isPresentingNewReminderForm = false
    @State private var reminderBeingEdited: Reminder?
    @State private var reminderPendingDeletion: Reminder?

    private let audioService = AudioGenerationService()

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
                                .contentShape(Rectangle())
                                .onTapGesture { reminderBeingEdited = reminder }
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
                                .swipeActions(edge: .leading) {
                                    Button {
                                        reminderBeingEdited = reminder
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(Color.appPrimary)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        reminderPendingDeletion = reminder
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground)
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Reminder", systemImage: "plus") { isPresentingNewReminderForm = true }
                }
            }
            .sheet(isPresented: $isPresentingNewReminderForm) {
                ReminderFormView()
            }
            .sheet(item: $reminderBeingEdited) { reminder in
                ReminderFormView(reminder: reminder)
            }
            .alert(
                "Delete Reminder?",
                isPresented: Binding(
                    get: { reminderPendingDeletion != nil },
                    set: { isPresented in
                        if !isPresented { reminderPendingDeletion = nil }
                    }
                ),
                presenting: reminderPendingDeletion
            ) { reminder in
                Button("Delete", role: .destructive) { delete(reminder) }
                Button("Cancel", role: .cancel) {}
            } message: { reminder in
                Text("\"\(reminder.title)\" will be permanently deleted.")
            }
        }
    }

    private func delete(_ reminder: Reminder) {
        Task {
            try? await audioService.deleteAudio(for: reminder.id)
            modelContext.delete(reminder)
        }
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
