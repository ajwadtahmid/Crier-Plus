import AVFoundation
import SwiftData
import SwiftUI

// Phase 1 checkpoint scaffolding only — replaced by ReminderListView in Phase 4.
struct DebugReminderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.createdAt, order: .reverse) private var reminders: [Reminder]
    @State private var audioPlayer: AVAudioPlayer?
    @State private var errorMessage: String?

    private let audioService = AudioGenerationService()

    var body: some View {
        NavigationStack {
            List {
                ForEach(reminders) { reminder in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.title)
                            Text(reminder.scheduleDescription())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Generate & Play", systemImage: "speaker.wave.2", action: {
                            generateAndPlay(reminder)
                        })
                        .labelStyle(.iconOnly)
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
            .alert("Audio Generation Failed", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
                Button("OK") { errorMessage = nil }
            } message: { message in
                Text(message)
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

    private func generateAndPlay(_ reminder: Reminder) {
        Task {
            do {
                let fileURL = try await audioService.generateAudio(
                    for: reminder.id,
                    message: reminder.spokenMessage
                )
                try AudioGenerationService.activatePlaybackSession()
                let player = try AVAudioPlayer(contentsOf: fileURL)
                audioPlayer = player
                player.prepareToPlay()
                if !player.play() {
                    errorMessage = "Playback didn't start (AVAudioPlayer.play() returned false)."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    DebugReminderListView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
