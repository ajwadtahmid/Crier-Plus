import AVFoundation
import Foundation

actor AudioGenerationService {
    private let synthesizer = AVSpeechSynthesizer()
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Renders `message` to a `.caf` file in Application Support, replacing any prior render for
    /// this reminder, using the voice/rate/pitch currently stored in `AppStorageKeys`.
    @discardableResult
    func generateAudio(for reminderID: UUID, message: String) async throws -> URL {
        let fileURL = try Self.audioFileURL(for: reminderID)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }

        let utterance = makeUtterance(for: message)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let writer = SpeechBufferWriter(fileURL: fileURL)
            synthesizer.write(utterance) { buffer in
                guard writer.handle(buffer) else { return }
                if let error = writer.writeError {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        return fileURL
    }

    /// Speaks `message` live using the currently stored voice/rate/pitch, for in-app preview.
    func speakPreview(_ message: String) throws {
        try Self.activatePlaybackSession()
        synthesizer.speak(makeUtterance(for: message))
    }

    private func makeUtterance(for message: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: message)
        if let voiceIdentifier = userDefaults.string(forKey: AppStorageKeys.voiceIdentifier),
            let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        {
            utterance.voice = voice
        }
        utterance.rate =
            userDefaults.object(forKey: AppStorageKeys.speechRate) != nil
            ? userDefaults.float(forKey: AppStorageKeys.speechRate)
            : AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier =
            userDefaults.object(forKey: AppStorageKeys.speechPitch) != nil
            ? userDefaults.float(forKey: AppStorageKeys.speechPitch)
            : 1.0
        return utterance
    }
}

extension AudioGenerationService {
    static func audioDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appendingPathComponent("Audio", isDirectory: true)
    }

    static func audioFileURL(for reminderID: UUID) throws -> URL {
        try audioDirectory().appendingPathComponent("\(reminderID.uuidString).caf")
    }

    static func availableVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
    }

    static func requestPersonalVoiceAuthorization() async -> AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus {
        await withCheckedContinuation { continuation in
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    static func activatePlaybackSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback)
        try session.setActive(true)
    }
}

/// Accumulates `AVSpeechSynthesizer.write`'s buffer callbacks into an `AVAudioFile`. Apple
/// guarantees these callbacks fire serially for a given utterance, so this type's mutable state
/// is never touched concurrently despite being handed to an `@escaping` callback.
private final class SpeechBufferWriter: @unchecked Sendable {
    private let fileURL: URL
    private var audioFile: AVAudioFile?
    private(set) var writeError: Error?
    private var hasFinished = false

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Returns `true` once the terminal (zero-length) buffer has been received. Some voices
    /// (observed with Simulator fallback voices) can emit more than one zero-length buffer for a
    /// single utterance, so any callback after the first terminal signal is ignored rather than
    /// resuming the caller's continuation a second time.
    func handle(_ buffer: AVAudioBuffer) -> Bool {
        guard !hasFinished else { return false }
        guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return false }
        guard pcmBuffer.frameLength > 0 else {
            hasFinished = true
            return true
        }
        do {
            if audioFile == nil {
                audioFile = try AVAudioFile(
                    forWriting: fileURL,
                    settings: pcmBuffer.format.settings,
                    commonFormat: pcmBuffer.format.commonFormat,
                    interleaved: pcmBuffer.format.isInterleaved
                )
            }
            try audioFile?.write(from: pcmBuffer)
        } catch {
            writeError = error
        }
        return false
    }
}
