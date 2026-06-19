import Foundation
import SwiftUI

enum AppStorageKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let username = "username"
    static let speechRate = "speechRate"
    static let speechPitch = "speechPitch"
}

struct ScaleFeedbackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(duration: 0.3), value: configuration.isPressed)
    }
}
