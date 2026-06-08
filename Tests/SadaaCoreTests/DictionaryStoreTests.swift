import Testing
import Foundation
@testable import SadaaCore

@Suite struct DictionaryStoreTests {
    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("dict-\(UUID().uuidString).json")
    }

    @Test func testAddPersistsAndIsNewestFirst() {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = DictionaryStore(fileURL: url)
        store.add(word: "Karko AI")
        store.add(word: "Supabase")
        #expect(store.all().map(\.word) == ["Supabase", "Karko AI"])

        let reopened = DictionaryStore(fileURL: url)
        #expect(reopened.all().map(\.word) == ["Supabase", "Karko AI"])
    }

    @Test func testAddDeDupesCaseInsensitiveAndMovesToFront() {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = DictionaryStore(fileURL: url)
        store.add(word: "Karko")
        store.add(word: "Vercel")
        store.add(word: "karko")
        #expect(store.all().count == 2)
        #expect(store.all().first?.word == "karko")
    }

    @Test func testBiasListPersonalFirstThenBaseCapped() {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = DictionaryStore(fileURL: url)
        store.add(word: "Zzzpersonal")
        let list = store.biasList(budget: 5)
        #expect(list.first == "Zzzpersonal")
        #expect(list.count == 5)
    }

    @Test func testBiasListDeDupesAgainstBase() {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = DictionaryStore(fileURL: url)
        store.add(word: "supabase") // also in base vocab
        let list = store.biasList(budget: 100)
        let occurrences = list.filter { $0.lowercased() == "supabase" }.count
        #expect(occurrences == 1)
        #expect(list.first == "supabase")
    }

    @Test func testSuggestExcludesPersonalDismissedAndDuplicates() {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = DictionaryStore(fileURL: url)
        store.add(word: "Existing")
        store.suggest(["Existing", "Newterm", "Newterm"])
        #expect(store.pendingSuggestions() == ["Newterm"])
    }

    @Test func testAcceptMovesToPersonal() {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = DictionaryStore(fileURL: url)
        store.suggest(["Karko"])
        store.accept("Karko")
        #expect(store.pendingSuggestions().isEmpty)
        #expect(store.all().first?.word == "Karko")
    }

    @Test func testDismissPreventsResuggestion() {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = DictionaryStore(fileURL: url)
        store.suggest(["Junk"])
        store.dismiss("Junk")
        store.suggest(["Junk"])
        #expect(store.pendingSuggestions().isEmpty)
    }

    @Test func testCorruptFileRecoversToEmptyWithBackup() throws {
        let url = tempFile()
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("bak"))
        }
        try Data("{ not json".utf8).write(to: url)
        let store = DictionaryStore(fileURL: url)
        #expect(store.all().isEmpty)
        #expect(FileManager.default.fileExists(
            atPath: url.appendingPathExtension("bak").path))
    }
}
