import UserNotifications

/// Without this, `UNUserNotificationCenter` silently suppresses a notification's banner and sound
/// whenever the app is in the foreground — indistinguishable from the reminder never firing.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    private override init() {}

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard
            let reminderIDString = response.notification.request.content.userInfo["reminderID"] as? String,
            let reminderID = UUID(uuidString: reminderIDString)
        else {
            completionHandler()
            return
        }

        let actionIdentifier = response.actionIdentifier
        let completion = CompletionHandlerBox(completionHandler)
        Task {
            switch actionIdentifier {
            case NotificationService.snoozeActionIdentifier:
                _ = try? await AlarmActionHandler().snooze(reminderID: reminderID, path: .notification)
            case NotificationService.dismissActionIdentifier:
                _ = try? await AlarmActionHandler().dismiss(reminderID: reminderID, path: .notification)
            default:
                await RingPresentationCoordinator.shared.present(reminderID: reminderID, path: .notification)
            }
            completion.call()
        }
    }
}

/// `UNNotificationResponse`'s completion handler predates Swift 6 concurrency and isn't
/// `Sendable`, so it can't be captured directly inside a `Task {}`; this box makes the capture
/// explicit and intentional rather than fighting the compiler with an unsafe cast at the call site.
private final class CompletionHandlerBox: @unchecked Sendable {
    private let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    func call() {
        handler()
    }
}
