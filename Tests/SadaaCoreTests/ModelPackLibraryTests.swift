import Testing
import Foundation
@testable import SadaaCore

@Suite(.serialized) struct ModelPackLibraryTests {
    /// A fresh temp directory per test, removed at the end.
    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sadaa-modelpacks-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func testBuiltInPackReturnedWhenNoOverride() {
        let pack = ModelPackLibrary.pack(for: .claude)
        #expect(pack.id == .claude)
        #expect(pack.guidance.contains("Lead with context, then the instruction."))
    }

    @Test func testBuiltInPackReturnedWhenOverrideDirEmpty() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let pack = ModelPackLibrary.pack(for: .gpt, overridesDirectory: dir)
        #expect(pack.guidance.contains("follow instructions very literally"))
    }

    @Test func testOverrideFileReplacesGuidance() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let custom = "My own Claude guidance."
        try custom.write(to: dir.appendingPathComponent("claude.md"),
                         atomically: true, encoding: .utf8)
        let pack = ModelPackLibrary.pack(for: .claude, overridesDirectory: dir)
        #expect(pack.guidance == custom)
    }

    @Test func testEmptyOverrideFileIsIgnored() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try "   \n  ".write(to: dir.appendingPathComponent("gpt.md"),
                            atomically: true, encoding: .utf8)
        let pack = ModelPackLibrary.pack(for: .gpt, overridesDirectory: dir)
        #expect(pack.guidance.contains("follow instructions very literally"))
    }

    @Test func testSeedOverridesWritesAllFourPacks() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try ModelPackLibrary.seedOverrides(into: dir)
        for id in ModelPackID.allCases {
            let url = dir.appendingPathComponent("\(id.rawValue).md")
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test func testSeedOverridesNeverClobbersAnEditedFile() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let edited = "Edited by the user, keep me."
        try edited.write(to: dir.appendingPathComponent("claude.md"),
                         atomically: true, encoding: .utf8)
        try ModelPackLibrary.seedOverrides(into: dir)
        let after = try String(
            contentsOf: dir.appendingPathComponent("claude.md"), encoding: .utf8)
        #expect(after == edited)
        // The packs the user had not touched are still written.
        #expect(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("gpt.md").path))
    }
}
