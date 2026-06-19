import Foundation
import FoundationModels

enum AIAvailabilityStatus {
    case ready
    case unsupportedDevice
    case needsToEnableInSettings
    case downloading
    case unknown
}

func checkAIAvailability() -> AIAvailabilityStatus {
    switch SystemLanguageModel.default.availability {
    case .available:
        return .ready
    case .unavailable(.deviceNotEligible):
        return .unsupportedDevice
    case .unavailable(.appleIntelligenceNotEnabled):
        return .needsToEnableInSettings
    case .unavailable(.modelNotReady):
        return .downloading
    default:
        return .unknown
    }
}
