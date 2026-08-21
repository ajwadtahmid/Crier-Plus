import Testing

@testable import CrierPlus

struct VoiceDisplayTests {
    /// `AVSpeechSynthesisVoice` has no public initializer, so this exercises the real logic
    /// against whatever voices actually exist on the running system rather than a fake — a
    /// Personal Voice may or may not be present, but either way every voice must be labeled
    /// according to its actual trait, never the other way around.
    @Test
    func personalVoicesAreLabeledDistinctlyAndOthersAreNot() {
        let voices = AudioGenerationService.availableVoices()

        for voice in voices where voice.voiceTraits.contains(.isPersonalVoice) {
            #expect(VoiceDisplay.label(for: voice).hasSuffix("(Personal Voice)"))
        }
        for voice in voices where !voice.voiceTraits.contains(.isPersonalVoice) {
            #expect(VoiceDisplay.label(for: voice) == voice.name)
        }
    }
}
