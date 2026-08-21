import FoundationModels
import Testing

@testable import CrierPlus

struct MessageWriterServiceTests {
    @Test
    func suggestionsUseTheTemplateFallbackWhenUnavailable() async throws {
        let generator = FakeMessageGenerator()
        let service = MessageWriterService(
            availability: FakeAIAvailability(status: .unavailable(reason: "test")),
            generator: generator
        )

        let suggestions = try await service.suggestions(forTitle: "Take a walk")

        #expect(suggestions.friendly.contains("take a walk"))
        #expect(suggestions.motivating.contains("take a walk"))
        #expect(suggestions.direct == "Take a walk.")
        #expect(generator.suggestionsRequests.isEmpty)
    }

    @Test
    func rewriteUsesTheTemplateFallbackWhenUnavailable() async throws {
        let generator = FakeMessageGenerator()
        let service = MessageWriterService(
            availability: FakeAIAvailability(status: .unavailable(reason: "test")),
            generator: generator
        )

        let rewritten = try await service.rewrite(message: "Time to take a walk!", tone: .urgent)

        #expect(rewritten == "Important — Time to take a walk!")
        #expect(generator.rewriteRequests.isEmpty)
    }

    @Test
    func suggestionsCallTheGeneratorWhenAvailable() async throws {
        let generator = FakeMessageGenerator()
        let service = MessageWriterService(availability: FakeAIAvailability(status: .available), generator: generator)

        let suggestions = try await service.suggestions(forTitle: "Take a walk")

        #expect(suggestions.friendly == "friendly")
        #expect(generator.suggestionsRequests == ["Take a walk"])
    }

    @Test
    func guardrailViolationMapsToAnActionableMessageInsteadOfAGenericFailure() async throws {
        let generator = FakeMessageGenerator()
        generator.suggestionsResult = .failure(
            LanguageModelSession.GenerationError.guardrailViolation(.init(debugDescription: "unsafe content"))
        )
        let service = MessageWriterService(availability: FakeAIAvailability(status: .available), generator: generator)

        do {
            _ = try await service.suggestions(forTitle: "Take a walk")
            Issue.record("Expected suggestions(forTitle:) to throw")
        } catch let error as MessageWriterError {
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.isEmpty == false)
        } catch {
            Issue.record("Expected MessageWriterError, got \(error)")
        }
    }

    @Test
    func nonGuardrailErrorsPropagateUnchanged() async throws {
        struct OtherError: Error {}
        let generator = FakeMessageGenerator()
        generator.rewriteResult = .failure(OtherError())
        let service = MessageWriterService(availability: FakeAIAvailability(status: .available), generator: generator)

        await #expect(throws: OtherError.self) {
            try await service.rewrite(message: "Time to take a walk!", tone: .funny)
        }
    }
}
