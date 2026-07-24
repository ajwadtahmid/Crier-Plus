import Testing

@testable import CrierPlus

struct RootDestinationTests {
    @Test
    func onboardingWhenNotCompleted() {
        #expect(RootDestination(hasCompletedOnboarding: false) == .onboarding)
    }

    @Test
    func mainWhenCompleted() {
        #expect(RootDestination(hasCompletedOnboarding: true) == .main)
    }
}
