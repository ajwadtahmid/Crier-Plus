import AVFoundation

/// Pulled out of `SettingsView` so the Personal Voice labeling logic is unit-testable —
/// `AVSpeechSynthesisVoice` has no public initializer, so tests exercise this against whatever
/// voices actually exist on the running system rather than a fake.
enum VoiceDisplay {
    static func label(for voice: AVSpeechSynthesisVoice) -> String {
        voice.voiceTraits.contains(.isPersonalVoice) ? "\(voice.name) (Personal Voice)" : voice.name
    }
}
