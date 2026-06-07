import Testing
import Foundation
@testable import SadaaCore

@Suite final class DictationHistoryTests {
    private let dir: URL
    private let fileURL: URL

    init() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hist-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.json")
    }

    deinit {
        try? FileManager.default.removeItem(at: dir)
    }

    private func record(_ text: String, at date: Date) -> DictationRecord {
        DictationRecord(text: text, createdAt: date, language: "en",
                        provider: "azure", durationSeconds: 1.5)
    }

    @Test func testRoundTripPersists() throws {
        let history = DictationHistory(fileURL: fileURL)
        let first = record("first", at: Date(timeIntervalSince1970: 1_000))
        let second = record("second", at: Date(timeIntervalSince1970: 2_000))
        history.append(first)
        history.append(second)

        let reloaded = DictationHistory(fileURL: fileURL)
        let all = reloaded.all()
        #expect(all.count == 2)
        #expect(all[0] == second)
        #expect(all[1] == first)
    }

    @Test func testRecentCaps() throws {
        let history = DictationHistory(fileURL: fileURL)
        history.append(record("a", at: Date(timeIntervalSince1970: 1_000)))
        history.append(record("b", at: Date(timeIntervalSince1970: 2_000)))
        let newest = record("c", at: Date(timeIntervalSince1970: 3_000))
        history.append(newest)

        #expect(history.recent(1).count == 1)
        #expect(history.recent(1).first == newest)
        #expect(history.recent(10).count == 3)
    }

    @Test func testSearchCaseInsensitive() throws {
        let history = DictationHistory(fileURL: fileURL)
        let hello = record("Hello World", at: Date(timeIntervalSince1970: 1_000))
        let guten = record("Guten Tag", at: Date(timeIntervalSince1970: 2_000))
        history.append(hello)
        history.append(guten)

        let hits = history.search("hello")
        #expect(hits.count == 1)
        #expect(hits.first == hello)
        #expect(history.search("  ").count == 2)
    }

    @Test func testCorruptFileRecovers() throws {
        try Data("{ not json".utf8).write(to: fileURL)
        let history = DictationHistory(fileURL: fileURL)
        #expect(history.all().isEmpty)
        let backup = fileURL.appendingPathExtension("bak")
        #expect(FileManager.default.fileExists(atPath: backup.path))
    }

    @Test func testRecordCodableRoundTrip() throws {
        let original = DictationRecord(text: "round trip",
                                       createdAt: Date(timeIntervalSince1970: 1_234),
                                       language: "de", provider: "azure",
                                       durationSeconds: 3.25)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DictationRecord.self, from: data)
        #expect(decoded == original)
    }
}
