import Foundation
import FoundationModels

enum MessageTone: String, CaseIterable {
    case friendly = "friendly"
    case motivating = "motivating"
    case urgent = "urgent"
    case funny = "funny"

    var displayName: String {
        rawValue.capitalized
    }
}

final class MessageWriterService {
    static let shared = MessageWriterService()
    private init() {}

    func generateSuggestions(title: String, username: String) async throws -> MessageSuggestions {
        let session = LanguageModelSession(instructions: """
            You write spoken reminder messages for an iOS app. Each message will be spoken aloud using text-to-speech.
            The message should address the user by name and remind them of the task.
            Keep messages concise (under 20 words), natural when spoken, and end with the task clearly stated.
            User's name: \(username). Reminder title: \(title).
            """)

        let prompt = "Write three versions of a spoken reminder message for '\(title)' addressed to \(username)."
        return try await session.respond(to: prompt, generating: MessageSuggestions.self)
    }

    func rewrite(message: String, tone: MessageTone) async throws -> String {
        let session = LanguageModelSession(instructions: """
            You rewrite spoken reminder messages for an iOS text-to-speech app.
            Keep the same core content but change the tone. Messages should sound natural when spoken aloud.
            Keep it under 25 words.
            """)

        let prompt = "Rewrite this reminder message in a \(tone.displayName) tone: \"\(message)\""
        let response = try await session.respond(to: prompt)
        return response.content
    }

    func templateFallback(username: String, title: String) -> String {
        "\(username), \(title). \(username), \(title)."
    }
}
