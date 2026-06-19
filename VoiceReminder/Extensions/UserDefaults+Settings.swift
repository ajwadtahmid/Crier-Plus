import Foundation
import SwiftUI

extension UserDefaults {
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    static let usernameKey = "username"
    static let speechRateKey = "speechRate"
    static let speechPitchKey = "speechPitch"
}

// AppStorage property wrapper keys used across the app
enum AppStorageKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let username = "username"
    static let speechRate = "speechRate"
    static let speechPitch = "speechPitch"
}
