import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermission() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    func schedule(_ reminder: Reminder) async throws {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body  = reminder.spokenMessage
        content.userInfo = ["reminderId": reminder.id.uuidString]

        // UNNotificationSound(named:) only resolves files inside Library/Sounds/.
        // Copy the file there and reference by filename only.
        if let audioPath = reminder.audioFilePath,
           let soundName = installSoundFile(from: audioPath) {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        } else {
            content.sound = .default
        }

        let calendar = Calendar.current

        switch reminder.repeatPattern {
        case .none:
            // Full date components so the trigger fires exactly once at the right date/time.
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminder.scheduledTime
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: reminder.id.uuidString,
                content: content,
                trigger: trigger
            )
            try await UNUserNotificationCenter.current().add(request)

        case .daily:
            let components = calendar.dateComponents([.hour, .minute], from: reminder.scheduledTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: reminder.id.uuidString,
                content: content,
                trigger: trigger
            )
            try await UNUserNotificationCenter.current().add(request)

        case .weekdays:
            for weekday in 2...6 {
                var components = calendar.dateComponents([.hour, .minute], from: reminder.scheduledTime)
                components.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "\(reminder.id.uuidString)-\(weekday)",
                    content: content,
                    trigger: trigger
                )
                try await UNUserNotificationCenter.current().add(request)
            }

        case .weekly:
            var components = calendar.dateComponents([.hour, .minute], from: reminder.scheduledTime)
            components.weekday = calendar.component(.weekday, from: reminder.scheduledTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: reminder.id.uuidString,
                content: content,
                trigger: trigger
            )
            try await UNUserNotificationCenter.current().add(request)

        case .custom:
            for weekday in reminder.repeatDays {
                var components = calendar.dateComponents([.hour, .minute], from: reminder.scheduledTime)
                components.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "\(reminder.id.uuidString)-\(weekday)",
                    content: content,
                    trigger: trigger
                )
                try await UNUserNotificationCenter.current().add(request)
            }
        }
    }

    func cancel(_ reminderId: UUID) {
        let base = reminderId.uuidString
        let ids   = [base] + (1...7).map { "\(base)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Private

    /// Copies the audio file into Library/Sounds/ (required by UNNotificationSound)
    /// and returns the filename, or nil if the copy fails.
    private func installSoundFile(from audioPath: String) -> String? {
        let source   = URL(fileURLWithPath: audioPath)
        let library  = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsDir = library.appendingPathComponent("Sounds")
        let dest     = soundsDir.appendingPathComponent(source.lastPathComponent)

        do {
            if !FileManager.default.fileExists(atPath: soundsDir.path) {
                try FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
            }
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: source, to: dest)
            return source.lastPathComponent
        } catch {
            return nil
        }
    }
}
