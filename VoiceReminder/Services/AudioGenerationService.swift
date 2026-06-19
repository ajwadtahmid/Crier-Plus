import Foundation
import AVFoundation

final class AudioGenerationService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var writeCompletion: ((Result<URL, Error>) -> Void)?
    private var outputURL: URL?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func generateAudio(for reminder: Reminder, message: String) async throws -> URL {
        let rate = UserDefaults.standard.object(forKey: AppStorageKey.speechRate) as? Float ?? 0.5
        let pitch = UserDefaults.standard.object(forKey: AppStorageKey.speechPitch) as? Float ?? 1.0

        let fileName = "reminder_\(reminder.id.uuidString).caf"
        let soundsURL = try soundsDirectory()
        let outputURL = soundsURL.appendingPathComponent(fileName)

        // Remove existing file for this reminder
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch

        return try await withCheckedThrowingContinuation { continuation in
            self.writeCompletion = { result in
                continuation.resume(with: result)
            }
            self.outputURL = outputURL

            synthesizer.write(utterance) { [weak self] buffer in
                guard let self, let url = self.outputURL else { return }
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

                do {
                    let audioFile = try AVAudioFile(forWriting: url, settings: pcmBuffer.format.settings)
                    try audioFile.write(from: pcmBuffer)
                } catch {
                    self.writeCompletion?(.failure(error))
                    self.writeCompletion = nil
                }
            }

            // Completion is signalled after synthesis finishes (delegate)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard let url = outputURL else { return }
        writeCompletion?(.success(url))
        writeCompletion = nil
    }

    func speakPreview(_ message: String) {
        let rate = UserDefaults.standard.object(forKey: AppStorageKey.speechRate) as? Float ?? 0.5
        let pitch = UserDefaults.standard.object(forKey: AppStorageKey.speechPitch) as? Float ?? 1.0

        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }

        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        synthesizer.speak(utterance)
    }

    func deleteAudio(at path: String?) {
        guard let path else { return }
        try? FileManager.default.removeItem(atPath: path)
    }

    private func soundsDirectory() throws -> URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let sounds = library.appendingPathComponent("Sounds")
        if !FileManager.default.fileExists(atPath: sounds.path) {
            try FileManager.default.createDirectory(at: sounds, withIntermediateDirectories: true)
        }
        return sounds
    }
}
