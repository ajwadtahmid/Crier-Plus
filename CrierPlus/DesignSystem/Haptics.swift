import UIKit

/// Thin wrapper over `UINotificationFeedbackGenerator`/`UIImpactFeedbackGenerator` so views never
/// touch UIKit feedback generators directly. Each call creates and immediately fires its own
/// generator — Apple's guidance is that generators are cheap to create per-use and don't need to
/// be retained/prepared ahead of time for occasional, user-initiated feedback like this.
@MainActor
enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func toggle() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
