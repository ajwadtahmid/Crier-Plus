import Foundation
import AVFoundation

final class AudioGenerationService {
    // Separate synthesizers: write() and speak() conflict on the same instance
    private let writeSynth = AVSpeechSynthesizer()
    private let previewSynth = AVSpeechSynthesizer()

    func generateAudio(for reminder: Reminder, message: String) async throws -> URL {
        let rate  = UserDefaults.standard.object(forKey: AppStorageKey.speechRate)  as? Float ?? 0.5
        let pitch = UserDefaults.standard.object(forKey: AppStorageKey.speechPitch) as? Float ?? 1.0

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = docs.appendingPathComponent("reminder_\(reminder.id.uuidString).caf")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch

        return try await withCheckedThrowingContinuation { continuation in
            var audioFile: AVAudioFile?
            var resumed = false

            writeSynth.write(utterance) { buffer in
                guard !resumed, let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

                // Empty buffer signals end of synthesis
                if pcmBuffer.frameLength == 0 {
                    resumed = true
                    continuation.resume(returning: outputURL)
                    return
                }

                do {
                    if audioFile == nil {
                        // Open the file once using the format from the first real buffer
                        audioFile = try AVAudioFile(forWriting: outputURL,
                                                    settings: pcmBuffer.format.settings)
                    }
                    try audioFile?.write(from: pcmBuffer)
                } catch {
                    resumed = true
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func speakPreview(_ message: String) {
        let rate  = UserDefaults.standard.object(forKey: AppStorageKey.speechRate)  as? Float ?? 0.5
        let pitch = UserDefaults.standard.object(forKey: AppStorageKey.speechPitch) as? Float ?? 1.0

        if previewSynth.isSpeaking { previewSynth.stopSpeaking(at: .immediate) }

        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        previewSynth.speak(utterance)
    }

    func deleteAudio(at path: String?) {
        guard let path else { return }
        try? FileManager.default.removeItem(atPath: path)
    }
}
