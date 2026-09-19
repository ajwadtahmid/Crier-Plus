import AVFoundation
import Foundation

enum CustomSoundResolution: Equatable {
    case useCustomSound
    case fallbackTooLong(duration: TimeInterval)
}

enum CustomSoundResolver {
    /// Apple's documented soft limit for custom notification sounds — past this, iOS silently
    /// substitutes the default sound, so we detect it ourselves and warn instead.
    static let maximumDuration: TimeInterval = 30

    static func resolve(duration: TimeInterval) -> CustomSoundResolution {
        duration > maximumDuration ? .fallbackTooLong(duration: duration) : .useCustomSound
    }
}

/// Installs a reminder's rendered `.caf` into `Library/Sounds` as a custom alert sound, shared by
/// both delivery paths: `UNNotificationSound(named:)` for the notification path and
/// `ActivityKit.AlertConfiguration.AlertSound.named(_:)` for the AlarmKit path both resolve custom
/// sound names against this same directory.
enum CustomSoundInstaller {
    static func resolveSound(
        for reminder: ReminderSchedulingPayload
    ) async throws -> (soundName: String?, soundWarning: CustomSoundResolution?) {
        guard let audioFilePath = reminder.audioFilePath else { return (nil, nil) }
        let audioURL = try AudioGenerationService.audioDirectory().appendingPathComponent(audioFilePath)
        guard FileManager.default.fileExists(atPath: audioURL.path) else { return (nil, nil) }

        let duration = try Self.duration(ofAudioAt: audioURL)
        switch CustomSoundResolver.resolve(duration: duration) {
        case .useCustomSound:
            return (try Self.install(from: audioURL), nil)
        case .fallbackTooLong(let tooLongDuration):
            return (nil, .fallbackTooLong(duration: tooLongDuration))
        }
    }

    /// Removes a reminder's custom sound from `Library/Sounds`, if one was ever installed there —
    /// a no-op otherwise. Call this when a reminder is permanently deleted; cancelling its
    /// schedule alone leaves the file behind (by design, since a reschedule of the same reminder
    /// reinstalls it), so without this every reminder that ever used a custom sound orphans a file
    /// forever.
    static func remove(for reminderID: UUID) throws {
        let fileName = try AudioGenerationService.audioFileURL(for: reminderID).lastPathComponent
        let fileURL = try soundsDirectory().appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private static func duration(ofAudioAt url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.fileFormat.sampleRate
    }

    private static func install(from audioURL: URL) throws -> String {
        let destinationDirectory = try soundsDirectory()
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let destinationURL = destinationDirectory.appendingPathComponent(audioURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: audioURL, to: destinationURL)
        return audioURL.lastPathComponent
    }

    private static func soundsDirectory() throws -> URL {
        try FileManager.default.url(
            for: .libraryDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Sounds", isDirectory: true)
    }
}
