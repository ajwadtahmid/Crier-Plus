import Foundation
import Testing

@testable import CrierPlus

struct AudioGenerationServiceTests {
    private func makeService() -> AudioGenerationService {
        let suiteName = "AudioGenerationServiceTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        return AudioGenerationService(userDefaults: userDefaults)
    }

    @Test
    func generateAudioWritesNonEmptyCAFUnderApplicationSupport() async throws {
        let service = makeService()
        let reminderID = UUID()
        defer { try? FileManager.default.removeItem(at: try! AudioGenerationService.audioFileURL(for: reminderID)) }

        let fileURL = try await service.generateAudio(for: reminderID, message: "Time to take a walk.")

        #expect(fileURL.pathExtension == "caf")
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        #expect(fileURL.path.hasPrefix(appSupport.path))

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes[.size] as? Int ?? 0
        #expect(fileSize > 0)
    }

    @Test
    func regeneratingAudioReplacesThePriorFile() async throws {
        let service = makeService()
        let reminderID = UUID()
        defer { try? FileManager.default.removeItem(at: try! AudioGenerationService.audioFileURL(for: reminderID)) }

        let firstURL = try await service.generateAudio(for: reminderID, message: "Hi.")
        let firstAttributes = try FileManager.default.attributesOfItem(atPath: firstURL.path)
        let firstSize = firstAttributes[.size] as? Int ?? 0
        let firstModified = firstAttributes[.modificationDate] as? Date ?? .distantPast

        try await Task.sleep(nanoseconds: 1_000_000_000)

        let secondURL = try await service.generateAudio(
            for: reminderID,
            message: "This is a considerably longer reminder message than the first one."
        )
        let secondAttributes = try FileManager.default.attributesOfItem(atPath: secondURL.path)
        let secondSize = secondAttributes[.size] as? Int ?? 0
        let secondModified = secondAttributes[.modificationDate] as? Date ?? .distantPast

        #expect(firstURL == secondURL)
        #expect(secondSize > 0)
        #expect(secondSize != firstSize)
        #expect(secondModified > firstModified)
    }

    @Test
    func availableVoicesReturnsTheSystemDefaultSet() {
        let voices = AudioGenerationService.availableVoices()
        #expect(!voices.isEmpty)
    }
}
