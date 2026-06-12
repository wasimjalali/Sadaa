import Testing
import Foundation
@testable import SadaaCore

@Suite struct VoiceEditFormatterTests {
    private let config = AzureChatFormatter.Config(
        endpoint: URL(string: "https://myres.openai.azure.com")!,
        apiKey: "test-key", deployment: "gpt-4o-mini", apiVersion: "2024-10-21")

    private func ctx() -> FormattingContext {
        FormattingContext(appBundleID: nil, dictionaryWords: [],
                          speakerContext: "", language: .auto)
    }

    @Test func testRewriteRequestShape() throws {
        let formatter = AzureChatFormatter(config: config)
        let request = try formatter.makeRewriteRequest(
            selection: "teh cat", instruction: "fix the typo", context: ctx())
        #expect(request.url?.absoluteString ==
            "https://myres.openai.azure.com/openai/deployments/gpt-4o-mini/chat/completions?api-version=2024-10-21")
        let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let messages = json["messages"] as! [[String: String]]
        // The system prompt now carries the compose-vs-transform contract.
        #expect(messages.first?["content"]?.contains("selected text") == true)
        #expect(messages.first?["content"]?.contains("COMPOSE") == true)
        // Instruction and selection are delimited in the user message.
        #expect(messages.last?["content"]?.contains("fix the typo") == true)
        #expect(messages.last?["content"]?.contains("teh cat") == true)
        #expect(messages.last?["content"]?.contains("<selection>") == true)
        // Rewrite returns prose, not JSON, so no json_object response_format.
        #expect(json["response_format"] == nil)
    }

    @Test func testParseContentReturnsPlainText() throws {
        let body = #"{"choices":[{"message":{"content":"the cat"}}]}"#
        #expect(try AzureChatFormatter.parseContent(Data(body.utf8)) == "the cat")
    }

    @Test func testParseContentEmptyThrows() {
        let body = #"{"choices":[{"message":{"content":"  "}}]}"#
        #expect(throws: ProviderError.self) {
            _ = try AzureChatFormatter.parseContent(Data(body.utf8))
        }
    }
}

@Suite @MainActor final class VoiceEditControllerTests {
    private let dir: URL
    private let store: RecordingStore
    private let recorder: FakeRecorder
    private var replaced: [String] = []
    private var states: [VoiceEditState] = []

    init() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ve-\(UUID().uuidString)")
        store = try RecordingStore(directory: dir)
        recorder = FakeRecorder()
        replaced = []
        states = []
    }

    deinit { try? FileManager.default.removeItem(at: dir) }

    private func make(selection: String?,
                      providers: [TranscriptionProvider],
                      rewrite: @escaping (String, String) async throws -> String)
        -> VoiceEditController {
        let controller = VoiceEditController(
            recorder: recorder,
            providers: { providers },
            store: store,
            hint: { TranscriptionHint(languagePin: .auto, dictionaryWords: []) },
            readSelection: { selection },
            rewrite: rewrite,
            replace: { [weak self] text in self?.replaced.append(text) })
        controller.onStateChange = { [weak self] s in self?.states.append(s) }
        return controller
    }

    @Test func testHappyPathRewritesSelection() async throws {
        let provider = FakeProvider(name: "fake",
            result: .success(Transcript(text: "make it formal",
                                        detectedLanguage: nil, durationSeconds: nil)))
        let controller = make(selection: "hey whats up", providers: [provider]) { sel, instr in
            #expect(sel == "hey whats up")
            #expect(instr == "make it formal")
            return "Hello, how are you?"
        }
        controller.toggle()
        #expect(controller.state == .recording)
        await controller.toggleAndWait()
        #expect(replaced == ["Hello, how are you?"])
        #expect(controller.state == .idle)
    }

    @Test func testNoSelectionErrors() {
        let controller = make(selection: nil, providers: []) { _, _ in "x" }
        controller.toggle()
        guard case .error = controller.state else {
            Issue.record("expected error"); return
        }
        #expect(replaced.isEmpty)
    }

    @Test func testRewriteFailureLeavesTextUnchanged() async {
        struct Boom: Error {}
        let provider = FakeProvider(name: "fake",
            result: .success(Transcript(text: "instr", detectedLanguage: nil,
                                        durationSeconds: nil)))
        let controller = make(selection: "original", providers: [provider]) { _, _ in
            throw Boom()
        }
        controller.toggle()
        await controller.toggleAndWait()
        #expect(replaced.isEmpty)
        guard case .error = controller.state else {
            Issue.record("expected error"); return
        }
    }
}
