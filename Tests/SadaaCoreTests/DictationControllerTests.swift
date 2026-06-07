import Testing
import Foundation
@testable import SadaaCore

final class FakeRecorder: AudioRecording {
    var onLevel: ((Float) -> Void)?
    var onAutoStop: (() -> Void)?
    var startedURL: URL?
    var cancelled = false

    func start(to url: URL) throws {
        startedURL = url
        try Data([0x00, 0x01]).write(to: url)
    }
    func stop() throws -> URL {
        guard let url = startedURL else { throw AudioRecorderError.notRecording }
        return url
    }
    func cancel() { cancelled = true }
}

struct FakeProvider: TranscriptionProvider {
    let name: String
    let result: Result<Transcript, Error>
    func transcribe(audio: URL, hint: TranscriptionHint) async throws -> Transcript {
        try result.get()
    }
}

@Suite final class DictationControllerTests {
    private let dir: URL
    private let store: RecordingStore
    private let recorder: FakeRecorder
    private var delivered: [String] = []
    private var states: [DictationState] = []

    init() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dict-\(UUID().uuidString)")
        store = try RecordingStore(directory: dir)
        recorder = FakeRecorder()
        delivered = []
        states = []
    }

    deinit {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeController(providers: [TranscriptionProvider])
        -> DictationController {
        let controller = DictationController(
            recorder: recorder,
            providers: { providers },
            store: store,
            hint: { TranscriptionHint(languagePin: .auto, dictionaryWords: []) },
            recordingsToKeep: 10,
            deliver: { [weak self] text in self?.delivered.append(text) }
        )
        controller.onStateChange = { [weak self] state in
            self?.states.append(state)
        }
        return controller
    }

    @Test func testHappyPath() async throws {
        let provider = FakeProvider(
            name: "fake",
            result: .success(Transcript(text: "hello world",
                                        detectedLanguage: "english",
                                        durationSeconds: 1)))
        let controller = makeController(providers: [provider])

        controller.toggle() // start
        #expect(controller.state == .recording)
        #expect(recorder.startedURL != nil)

        await controller.toggleAndWait() // stop + process
        #expect(delivered == ["hello world"])
        #expect(controller.state == .idle)
        let sidecar = recorder.startedURL!
            .deletingPathExtension().appendingPathExtension("txt")
        #expect(try String(contentsOf: sidecar, encoding: .utf8) == "hello world")
    }

    @Test func testFallbackChain() async throws {
        let failing = FakeProvider(name: "primary",
                                   result: .failure(ProviderError.http(500, "boom")))
        let working = FakeProvider(
            name: "secondary",
            result: .success(Transcript(text: "rescued",
                                        detectedLanguage: nil,
                                        durationSeconds: nil)))
        let controller = makeController(providers: [failing, working])

        controller.toggle()
        await controller.toggleAndWait()
        #expect(delivered == ["rescued"])
        #expect(controller.state == .idle)
    }

    @Test func testAllProvidersFailKeepsAudioAndReportsError() async throws {
        let failing = FakeProvider(name: "only",
                                   result: .failure(ProviderError.http(500, "boom")))
        let controller = makeController(providers: [failing])

        controller.toggle()
        await controller.toggleAndWait()
        #expect(delivered == [])
        guard case .error = controller.state else {
            Issue.record("expected error state, got \(controller.state)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: recorder.startedURL!.path))
    }

    @Test func testCancelDiscardsRecording() {
        let provider = FakeProvider(
            name: "fake",
            result: .success(Transcript(text: "x", detectedLanguage: nil,
                                        durationSeconds: nil)))
        let controller = makeController(providers: [provider])

        controller.toggle()
        controller.cancel()
        #expect(recorder.cancelled)
        #expect(controller.state == .idle)
        #expect(delivered == [])
    }

    @Test func testNoProvidersConfigured() async {
        let controller = makeController(providers: [])
        controller.toggle()
        await controller.toggleAndWait()
        guard case .error(let message) = controller.state else {
            Issue.record("expected error state")
            return
        }
        #expect(message.contains("provider"))
    }
}
