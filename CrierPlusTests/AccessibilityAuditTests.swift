import Foundation
import Testing

@testable import CrierPlus

/// A source-scanning check rather than a runtime one: Simulator test hosts run as ordinary macOS
/// processes, so the checked-out source tree is reachable via `#filePath` even though it wouldn't
/// be from a real device. This directly matches Phase 10's own checklist item ("a check that no
/// fixed font sizes remain") — a fixed point size bypasses Dynamic Type instead of using one of
/// `Theme.Typography`'s semantic fonts.
struct AccessibilityAuditTests {
    private static var sourceRoot: URL {
        // This file lives at <repo>/CrierPlusTests/AccessibilityAuditTests.swift.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("CrierPlus", isDirectory: true)
    }

    private static func swiftFiles(under directory: URL) -> [URL] {
        guard
            let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: nil
            )
        else { return [] }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    @Test
    func noFixedPointFontSizesRemainInSourceViews() throws {
        let files = Self.swiftFiles(under: Self.sourceRoot)
        #expect(!files.isEmpty, "Expected to find CrierPlus source files at \(Self.sourceRoot.path)")

        var offenders: [String] = []
        for file in files {
            let contents = try String(contentsOf: file, encoding: .utf8)
            for (lineNumber, line) in contents.components(separatedBy: .newlines).enumerated()
            where line.contains(".system(size:") {
                offenders.append("\(file.lastPathComponent):\(lineNumber + 1)")
            }
        }

        #expect(offenders.isEmpty, "Fixed point font size(s) found — use Theme.Typography instead: \(offenders)")
    }
}
