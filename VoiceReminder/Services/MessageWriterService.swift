import Foundation
import FoundationModels

enum MessageTone: String, CaseIterable {
    case friendly, motivating, urgent, funny
    var displayName: String { rawValue.capitalized }
}

enum MessageWriterError: LocalizedError {
    case unavailable
    var errorDescription: String? {
        "Apple Intelligence is not available on this device."
    }
}

final class MessageWriterService {
    static let shared = MessageWriterService()
    private init() {}

    // Callable from iOS 17+ — throws MessageWriterError.unavailable below iOS 26.
    func generateSuggestions(title: String, username: String) async throws -> MessageSuggestions {
        if #available(iOS 26, *) {
            return try await _generateSuggestions(title: title, username: username)
        }
        throw MessageWriterError.unavailable
    }

    // Callable from iOS 17+ — throws MessageWriterError.unavailable below iOS 26.
    func rewrite(message: String, tone: MessageTone) async throws -> String {
        if #available(iOS 26, *) {
            return try await _rewrite(message: message, tone: tone)
        }
        throw MessageWriterError.unavailable
    }

    func templateFallback(username: String, title: String) -> String {
        "\(username), \(title). \(username), \(title)."
    }

    // MARK: - iOS 26 implementations

    @available(iOS 26, *)
    private func _generateSuggestions(title: String, username: String) async throws -> MessageSuggestions {
        let session = LanguageModelSession(instructions: """
            You write spoken reminder messages for an iOS app. \
            Each message is read aloud via text-to-speech, so it must sound natural when spoken. \
            Address the user by name, state the task clearly, and keep it under 20 words.
            User's name: \(username). Reminder: \(title).
            """)
        let result = try await session.respond(
            to: "Write three spoken reminder messages for '\(title)' addressed to \(username).",
            generating: _AIMessageSuggestions.self
        )
        return MessageSuggestions(
            friendly: result.friendly,
            motivating: result.motivating,
            direct: result.direct
        )
    }

    @available(iOS 26, *)
    private func _rewrite(message: String, tone: MessageTone) async throws -> String {
        let session = LanguageModelSession(instructions: """
            You rewrite spoken reminder messages for an iOS text-to-speech app. \
            Keep the same core content but change the tone. \
            The result must sound natural when spoken aloud. Stay under 25 words.
            """)
        let response = try await session.respond(
            to: "Rewrite in a \(tone.displayName) tone: \"\(message)\""
        )
        return response.content
    }
}

// Private @Generable type — only referenced inside the @available(iOS 26, *) methods above.
@available(iOS 26, *)
@Generable
private struct _AIMessageSuggestions {
    @Guide(description: "A warm, friendly reminder message using the user's name")
    var friendly: String

    @Guide(description: "An energetic, motivating reminder message using the user's name")
    var motivating: String

    @Guide(description: "A clear, direct reminder message using the user's name")
    var direct: String
}
