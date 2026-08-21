import AppIntents
import Foundation

/// Runs when the system's Stop control on the alert is tapped — including while the app isn't
/// running, which is why this can't just be a method call from `AlarmRingView`. Deactivates a
/// one-time reminder the same way the in-app Dismiss button does; a repeating reminder is left
/// active since AlarmKit re-arms its own schedule automatically.
struct DismissAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Dismiss Reminder" }

    @Parameter(title: "Reminder ID")
    var reminderIDString: String

    init() {
        reminderIDString = ""
    }

    init(reminderID: UUID) {
        reminderIDString = reminderID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let reminderID = UUID(uuidString: reminderIDString) {
            try await AlarmActionHandler().dismiss(reminderID: reminderID, path: .alarm)
        }
        return .result()
    }
}
