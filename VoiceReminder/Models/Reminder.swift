import Foundation
import SwiftData

@Model
final class Reminder {
    var id: UUID
    var title: String
    var spokenMessage: String
    var scheduledTime: Date
    var repeatPattern: RepeatPattern
    var repeatDays: [Int]   // weekday numbers 1-7, used when repeatPattern == .custom
    var audioFilePath: String?
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        spokenMessage: String = "",
        scheduledTime: Date = Date(),
        repeatPattern: RepeatPattern = .none,
        repeatDays: [Int] = [],
        audioFilePath: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.spokenMessage = spokenMessage
        self.scheduledTime = scheduledTime
        self.repeatPattern = repeatPattern
        self.repeatDays = repeatDays
        self.audioFilePath = audioFilePath
        self.isActive = isActive
        self.createdAt = createdAt
    }
}
