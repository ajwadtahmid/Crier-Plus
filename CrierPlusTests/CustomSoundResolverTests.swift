import Testing

@testable import CrierPlus

struct CustomSoundResolverTests {
    @Test
    func shortDurationUsesTheCustomSound() {
        #expect(CustomSoundResolver.resolve(duration: 5) == .useCustomSound)
    }

    @Test
    func durationAtExactLimitUsesTheCustomSound() {
        #expect(CustomSoundResolver.resolve(duration: CustomSoundResolver.maximumDuration) == .useCustomSound)
    }

    @Test
    func durationOverLimitFallsBackAndReportsTheDuration() {
        #expect(CustomSoundResolver.resolve(duration: 31) == .fallbackTooLong(duration: 31))
    }
}
