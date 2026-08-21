import FoundationModels

enum AIAvailabilityStatus: Equatable, Sendable {
    case available
    case unavailable(reason: String)
}

/// Seam over `SystemLanguageModel.availability` so `MessageWriterService` can be driven by a fake
/// status in tests — the real check reflects actual on-device Apple Intelligence eligibility,
/// which unit tests can't control.
protocol AIAvailabilityChecking: Sendable {
    var status: AIAvailabilityStatus { get }
}

struct AIAvailability: AIAvailabilityChecking {
    private let model: SystemLanguageModel

    init(model: SystemLanguageModel = .default) {
        self.model = model
    }

    var status: AIAvailabilityStatus {
        switch model.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(reason: Self.message(for: reason))
        }
    }

    private static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to use AI-suggested messages."
        case .modelNotReady:
            return "Apple Intelligence is still getting ready — try again in a moment."
        @unknown default:
            return "Apple Intelligence isn't available on this device right now."
        }
    }
}
