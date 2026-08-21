import AlarmKit
import Foundation
import Observation

/// Bridges alert delivery — a tapped/actioned notification (`NotificationDelegate`) or an AlarmKit
/// alarm entering `.alerting` while the app happens to be running — into presenting
/// `AlarmRingView` from `RootView`. Views never talk to `UNUserNotificationCenter`/`AlarmManager`
/// directly; this is the seam that lets both delivery paths converge on the same screen.
@MainActor
@Observable
final class RingPresentationCoordinator {
    static let shared = RingPresentationCoordinator()

    struct Presentation: Identifiable, Equatable {
        let reminderID: UUID
        let path: SchedulingPath
        var id: UUID { reminderID }
    }

    var presentation: Presentation?

    private init() {}

    func present(reminderID: UUID, path: SchedulingPath) {
        presentation = Presentation(reminderID: reminderID, path: path)
    }

    func dismissPresentation() {
        presentation = nil
    }

    /// Runs for the app's lifetime (started from `RootView`'s `.task`); AlarmKit has no delegate
    /// callback, so this is the only way to notice an alarm alerting while the app is foregrounded.
    func observeAlarmAlerts() async {
        for await alarms in AlarmManager.shared.alarmUpdates {
            for alarm in alarms where alarm.state == .alerting {
                present(reminderID: alarm.id, path: .alarm)
            }
        }
    }
}
