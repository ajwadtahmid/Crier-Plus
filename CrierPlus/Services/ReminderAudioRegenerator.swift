import Foundation

/// Regenerates every reminder's rendered `.caf` against the currently stored voice/rate/pitch —
/// used when the user changes their name (spoken in messages) or any voice setting, so a
/// previously rendered file never drifts from what's actually configured. Also reschedules every
/// active reminder afterward: the notification path installs its custom sound from the rendered
/// file at schedule time, so without a reschedule here, an already-active reminder would keep
/// ringing with the *old* recording until the user happened to reopen and re-save it.
@MainActor
struct ReminderAudioRegenerator {
    private let audioService: AudioGenerationService
    private let scheduler: ReminderScheduler
    private let userDefaults: UserDefaults

    init(
        audioService: AudioGenerationService = AudioGenerationService(),
        scheduler: ReminderScheduler = ReminderScheduler(),
        userDefaults: UserDefaults = .standard
    ) {
        self.audioService = audioService
        self.scheduler = scheduler
        self.userDefaults = userDefaults
    }

    func regenerateAll(_ reminders: [Reminder]) async {
        let voiceIdentifier = userDefaults.string(forKey: AppStorageKeys.voiceIdentifier)
        for reminder in reminders {
            guard let fileURL = try? await audioService.generateAudio(for: reminder.id, message: reminder.spokenMessage)
            else { continue }
            reminder.audioFilePath = fileURL.lastPathComponent
            reminder.voiceIdentifier = voiceIdentifier

            if reminder.isActive {
                _ = try? await scheduler.schedule(ReminderSchedulingPayload(reminder))
            }
        }
    }
}
