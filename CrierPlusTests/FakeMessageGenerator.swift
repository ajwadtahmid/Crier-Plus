import Foundation

@testable import CrierPlus

/// Deterministic stand-in for `FoundationModelsMessageGenerator`, since a real
/// `LanguageModelSession` needs actual Apple Intelligence and isn't controllable from a test.
final class FakeMessageGenerator: MessageGenerating, @unchecked Sendable {
    var suggestionsResult: Result<ToneSuggestions, Error> = .success(
        ToneSuggestions(friendly: "friendly", motivating: "motivating", direct: "direct")
    )
    var rewriteResult: Result<String, Error> = .success("rewritten")

    private(set) var suggestionsRequests: [String] = []
    private(set) var rewriteRequests: [(message: String, tone: RewriteTone)] = []

    func generateSuggestions(title: String) async throws -> ToneSuggestions {
        suggestionsRequests.append(title)
        return try suggestionsResult.get()
    }

    func rewrite(message: String, tone: RewriteTone) async throws -> String {
        rewriteRequests.append((message, tone))
        return try rewriteResult.get()
    }
}

struct FakeAIAvailability: AIAvailabilityChecking {
    let status: AIAvailabilityStatus
}
