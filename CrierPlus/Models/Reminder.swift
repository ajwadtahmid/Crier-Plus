import Foundation
import SwiftData

@Model
final class Reminder {
    var id: UUID
    var title: String
    var spokenMessage: String
    var scheduledTime: Date
    var repeatPattern: RepeatPattern
    var repeatDays: [Int]
    var audioFilePath: String?
    var voiceIdentifier: String?
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        spokenMessage: String,
        scheduledTime: Date,
        repeatPattern: RepeatPattern = .none,
        repeatDays: [Int] = [],
        audioFilePath: String? = nil,
        voiceIdentifier: String? = nil,
        isActive: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.spokenMessage = spokenMessage
        self.scheduledTime = scheduledTime
        self.repeatPattern = repeatPattern
        self.repeatDays = repeatDays
        self.audioFilePath = audioFilePath
        self.voiceIdentifier = voiceIdentifier
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

extension Reminder {
    func scheduleDescription(now: Date = .now, calendar: Calendar = .current) -> String {
        repeatPattern.scheduleDescription(
            repeatDays: repeatDays,
            scheduledTime: scheduledTime,
            now: now,
            calendar: calendar
        )
    }
}
