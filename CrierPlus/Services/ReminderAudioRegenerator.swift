import Foundation

/// Regenerates every reminder's rendered `.caf` against the currently stored voice/rate/pitch —
/// used when the user changes their name (spoken in messages) or any voice setting, so a
/// previously rendered file never drifts from what's actually configured.
@MainActor
struct ReminderAudioRegenerator {
    private let audioService: AudioGenerationService
    private let userDefaults: UserDefaults

    init(audioService: AudioGenerationService = AudioGenerationService(), userDefaults: UserDefaults = .standard) {
        self.audioService = audioService
        self.userDefaults = userDefaults
    }

    func regenerateAll(_ reminders: [Reminder]) async {
        let voiceIdentifier = userDefaults.string(forKey: AppStorageKeys.voiceIdentifier)
        for reminder in reminders {
            guard let fileURL = try? await audioService.generateAudio(for: reminder.id, message: reminder.spokenMessage)
            else { continue }
            reminder.audioFilePath = fileURL.lastPathComponent
            reminder.voiceIdentifier = voiceIdentifier
        }
    }
}
