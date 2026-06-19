import Foundation
import FoundationModels

enum AIAvailabilityStatus {
    case ready
    case unsupportedDevice
    case needsToEnableInSettings
    case downloading
    case unknown
}

// Safe to call from any iOS version — does the #available check internally.
func checkAIAvailability() -> AIAvailabilityStatus {
    if #available(iOS 26, *) {
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
    return .unsupportedDevice
}
