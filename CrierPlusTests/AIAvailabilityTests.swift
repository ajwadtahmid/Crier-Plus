import Testing

@testable import CrierPlus

struct AIAvailabilityTests {
    /// `SystemLanguageModel.availability` reflects real on-device Apple Intelligence eligibility,
    /// which a unit test can't control — this just confirms our own mapping never produces an
    /// empty/unhelpful reason string, whichever way the real check comes back on this machine.
    @Test
    func statusIsAlwaysAvailableOrCarriesANonEmptyReason() {
        let status = AIAvailability().status
        switch status {
        case .available:
            break
        case .unavailable(let reason):
            #expect(!reason.isEmpty)
        }
    }
}
