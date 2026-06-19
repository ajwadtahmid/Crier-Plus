import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermission() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func schedule(_ reminder: Reminder) async throws {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.spokenMessage

        if let audioPath = reminder.audioFilePath {
            let soundURL = URL(fileURLWithPath: audioPath)
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundURL.lastPathComponent))
        } else {
            content.sound = .default
        }

        content.userInfo = ["reminderId": reminder.id.uuidString]

        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: reminder.scheduledTime)

        if reminder.repeatPattern == .custom {
            for weekday in reminder.repeatDays {
                components.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "\(reminder.id.uuidString)-\(weekday)",
                    content: content,
                    trigger: trigger
                )
                try await UNUserNotificationCenter.current().add(request)
            }
        } else {
            let repeats = reminder.repeatPattern != .none
            if reminder.repeatPattern == .weekdays {
                for weekday in 2...6 {
                    components.weekday = weekday
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let request = UNNotificationRequest(
                        identifier: "\(reminder.id.uuidString)-\(weekday)",
                        content: content,
                        trigger: trigger
                    )
                    try await UNUserNotificationCenter.current().add(request)
                }
            } else {
                if reminder.repeatPattern == .weekly {
                    components.weekday = calendar.component(.weekday, from: reminder.scheduledTime)
                }
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
                let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
                try await UNUserNotificationCenter.current().add(request)
            }
        }
    }

    func cancel(_ reminderId: UUID) {
        let center = UNUserNotificationCenter.current()
        let baseId = reminderId.uuidString
        let weekdayIds = (1...7).map { "\(baseId)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: [baseId] + weekdayIds)
    }
}
