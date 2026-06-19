import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var reminders: [Reminder]

    @AppStorage(AppStorageKey.username) private var username = ""
    @AppStorage(AppStorageKey.speechRate) private var speechRate = 0.5
    @AppStorage(AppStorageKey.speechPitch) private var speechPitch = 1.0

    @State private var editedUsername = ""
    @State private var showUsernameAlert = false
    @State private var isUpdatingAudio = false
    @State private var updateProgress = ""

    private let audioService = AudioGenerationService()

    var body: some View {
        NavigationStack {
            List {
                accountSection
                voiceSection
                aiSection
            }
            .navigationTitle("Settings")
            .onAppear { editedUsername = username }
            .alert("Update reminders?", isPresented: $showUsernameAlert) {
                Button("Cancel", role: .cancel) { editedUsername = username }
                Button("Update") {
                    username = editedUsername
                    Task { await regenerateAllAudio() }
                }
            } message: {
                Text("Regenerate spoken audio for all existing reminders with your new name?")
            }
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section("Account") {
            HStack {
                TextField("Your name", text: $editedUsername)
                    .frame(height: 44)
                Button("Change") {
                    guard !editedUsername.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    showUsernameAlert = true
                }
                .disabled(
                    editedUsername == username ||
                    editedUsername.trimmingCharacters(in: .whitespaces).isEmpty
                )
            }

            if isUpdatingAudio {
                HStack(spacing: 8) {
                    ProgressView().progressViewStyle(.circular)
                    Text(updateProgress.isEmpty ? "Updating reminders..." : updateProgress)
                        .font(.system(size: 14))
                        .foregroundStyle(Color("TextSecondary"))
                }
            } else if !updateProgress.isEmpty {
                Text(updateProgress)
                    .font(.system(size: 14))
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
    }

    private var voiceSection: some View {
        Section("Voice Settings") {
            // Speech Rate
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Speech Rate").font(.system(size: 16))
                    Spacer()
                    Button {
                        audioService.speakPreview("The quick brown fox")
                    } label: {
                        Image(systemName: "speaker.wave.2")
                    }
                }
                HStack {
                    Text("Slow")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("TextSecondary"))
                    Slider(value: $speechRate, in: 0.3...1.5)
                    Text("Fast")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("TextSecondary"))
                }
            }
            .padding(.vertical, 4)

            // Speech Pitch
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Speech Pitch").font(.system(size: 16))
                    Spacer()
                    Button {
                        audioService.speakPreview("The quick brown fox")
                    } label: {
                        Image(systemName: "speaker.wave.2")
                    }
                }
                HStack {
                    Text("Low")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("TextSecondary"))
                    Slider(value: $speechPitch, in: 0.5...2.0)
                    Text("High")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("TextSecondary"))
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var aiSection: some View {
        let status = checkAIAvailability()
        return Section("AI") {
            HStack {
                Text("Apple Intelligence")
                Spacer()
                switch status {
                case .ready:
                    Text("Ready").foregroundStyle(Color("Accent"))
                case .downloading:
                    Text("Downloading...").foregroundStyle(.orange)
                default:
                    Text("Not available").foregroundStyle(Color("TextSecondary"))
                }
            }

            if status != .ready {
                Text(statusDescription(status))
                    .font(.system(size: 14))
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
    }

    // MARK: - Audio regeneration

    private func regenerateAllAudio() async {
        guard !reminders.isEmpty else { return }
        let total = reminders.count
        var updated = 0
        var failed  = 0

        await MainActor.run { isUpdatingAudio = true }

        for reminder in reminders {
            await MainActor.run {
                updateProgress = "Updating \(updated + failed + 1)/\(total)..."
            }
            do {
                let url = try await audioService.generateAudio(
                    for: reminder, message: reminder.spokenMessage)
                reminder.audioFilePath = url.path
                if reminder.isActive {
                    try? await NotificationService.shared.schedule(reminder)
                }
                updated += 1
            } catch {
                failed += 1
            }
        }

        await MainActor.run {
            isUpdatingAudio = false
            updateProgress  = failed > 0
                ? "Updated \(updated)/\(total) (\(failed) failed)"
                : "Updated all \(total) reminders"
        }

        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await MainActor.run { updateProgress = "" }
    }

    // MARK: - Helpers

    private func statusDescription(_ status: AIAvailabilityStatus) -> String {
        switch status {
        case .unsupportedDevice:       return "Requires an Apple Intelligence-capable device"
        case .needsToEnableInSettings: return "Enable Apple Intelligence in Settings"
        case .downloading:             return "Apple Intelligence model is downloading"
        default:                       return "Apple Intelligence unavailable"
        }
    }
}
