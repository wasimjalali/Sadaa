import Testing
import Foundation
@testable import SadaaCore

@Suite struct SnippetStoreTests {
    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("snip-\(UUID().uuidString).json")
    }

    @Test func testAddPersistsNewestFirst() {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = SnippetStore(fileURL: url)
        store.add(trigger: "my sig", expansion: "Best, Wasim")
        store.add(trigger: "addr", expansion: "123 Main St")
        #expect(store.all().map(\.trigger) == ["addr", "my sig"])

        let reopened = SnippetStore(fileURL: url)
        #expect(reopened.all().map(\.trigger) == ["addr", "my sig"])
    }

    @Test func testAddIgnoresEmpty() {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = SnippetStore(fileURL: url)
        store.add(trigger: "", expansion: "x")
        store.add(trigger: "y", expansion: "  ")
        #expect(store.all().isEmpty)
    }

    @Test func testAddDeDupesTriggerCaseInsensitive() {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = SnippetStore(fileURL: url)
        store.add(trigger: "Sig", expansion: "one")
        store.add(trigger: "sig", expansion: "two")
        #expect(store.all().count == 1)
        #expect(store.all().first?.expansion == "two")
    }

    @Test func testRemove() {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = SnippetStore(fileURL: url)
        store.add(trigger: "a", expansion: "1")
        let id = store.all().first!.id
        store.remove(id: id)
        #expect(store.all().isEmpty)
    }

    @Test func testPromptBuilderIncludesSnippets() {
        let prompt = FormattingPromptBuilder.systemPrompt(
            profile: FormattingProfiles.default,
            dictionaryWords: [],
            speakerContext: "ctx",
            snippets: [Snippet(trigger: "my sig", expansion: "Best, Wasim")])
        #expect(prompt.contains("Expand these spoken shortcuts"))
        #expect(prompt.contains("\"my sig\" -> Best, Wasim"))
    }
}
