import Foundation
import FoundationModels

/// Three tone variants offered when suggesting a brand-new message from a reminder's title.
enum SuggestionTone: CaseIterable, Hashable, Sendable {
    case friendly
    case motivating
    case direct

    var displayName: String {
        switch self {
        case .friendly: return "Friendly"
        case .motivating: return "Motivating"
        case .direct: return "Direct"
        }
    }
}

/// Four tone variants offered when rewriting an existing message.
enum RewriteTone: String, CaseIterable, Hashable, Sendable {
    case friendly
    case motivating
    case urgent
    case funny

    var displayName: String {
        switch self {
        case .friendly: return "Friendly"
        case .motivating: return "Motivating"
        case .urgent: return "Urgent"
        case .funny: return "Funny"
        }
    }
}

@Generable
struct ToneSuggestions: Sendable {
    @Guide(description: "A friendly, warm phrasing of the reminder message")
    var friendly: String

    @Guide(description: "A motivating, encouraging phrasing of the reminder message")
    var motivating: String

    @Guide(description: "A direct, no-nonsense phrasing of the reminder message")
    var direct: String

    func text(for tone: SuggestionTone) -> String {
        switch tone {
        case .friendly: return friendly
        case .motivating: return motivating
        case .direct: return direct
        }
    }
}

enum MessageWriterError: LocalizedError {
    case guardrailViolation

    var errorDescription: String? {
        "That message didn't pass Apple Intelligence's safety guardrails. Try rephrasing the title or message."
    }
}

/// Seam over `LanguageModelSession` so tests can substitute a fake without Apple Intelligence.
protocol MessageGenerating: Sendable {
    func generateSuggestions(title: String) async throws -> ToneSuggestions
    func rewrite(message: String, tone: RewriteTone) async throws -> String
}

struct FoundationModelsMessageGenerator: MessageGenerating {
    private let session: LanguageModelSession

    init(
        session: LanguageModelSession = LanguageModelSession(
            instructions: "You write short, warm reminder messages that will be spoken aloud to the user."
        )
    ) {
        self.session = session
    }

    func generateSuggestions(title: String) async throws -> ToneSuggestions {
        let response = try await session.respond(
            to: "Write a short reminder message (under 200 characters) for a reminder titled \"\(title)\".",
            generating: ToneSuggestions.self
        )
        return response.content
    }

    func rewrite(message: String, tone: RewriteTone) async throws -> String {
        let response = try await session.respond(
            to: "Rewrite this reminder message in a \(tone.rawValue) tone, keeping it under 200 characters "
                + "and preserving its meaning: \"\(message)\""
        )
        return response.content
    }
}

/// `AIAvailability` gates the AI UI; when Apple Intelligence isn't available, every method here
/// falls back to a template offering the same feature surface (same tones, same call shape) rather
/// than a degraded one. A `LanguageModelSession.GenerationError.guardrailViolation` is caught and
/// mapped to `MessageWriterError.guardrailViolation` instead of surfacing as a generic failure.
actor MessageWriterService {
    private let availability: any AIAvailabilityChecking
    private let generator: any MessageGenerating

    init(
        availability: any AIAvailabilityChecking = AIAvailability(),
        generator: any MessageGenerating = FoundationModelsMessageGenerator()
    ) {
        self.availability = availability
        self.generator = generator
    }

    func suggestions(forTitle title: String) async throws -> ToneSuggestions {
        guard availability.status == .available else {
            return Self.templateSuggestions(forTitle: title)
        }
        do {
            return try await generator.generateSuggestions(title: title)
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            throw MessageWriterError.guardrailViolation
        }
    }

    func rewrite(message: String, tone: RewriteTone) async throws -> String {
        guard availability.status == .available else {
            return Self.templateRewrite(message: message, tone: tone)
        }
        do {
            return try await generator.rewrite(message: message, tone: tone)
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            throw MessageWriterError.guardrailViolation
        }
    }

    static func templateSuggestions(forTitle title: String) -> ToneSuggestions {
        let subject = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return ToneSuggestions(
            friendly: "Hey! Just a friendly reminder to \(subject.lowercased()).",
            motivating: "You've got this — time to \(subject.lowercased())!",
            direct: "\(subject)."
        )
    }

    static func templateRewrite(message: String, tone: RewriteTone) -> String {
        switch tone {
        case .friendly:
            return "Just a friendly note: \(message)"
        case .motivating:
            return "You've got this! \(message)"
        case .urgent:
            return "Important — \(message)"
        case .funny:
            return "\(message) 😄"
        }
    }
}
