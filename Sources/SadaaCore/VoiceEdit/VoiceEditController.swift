import Foundation

public enum VoiceEditState: Equatable, Sendable {
    case idle
    case recording
    case rewriting
    case error(String)
}

/// Voice-edit pipeline. Spec section 4 (VoiceEditService): on toggle, capture
/// the current selection and record a spoken instruction; on the next toggle,
/// transcribe the instruction, rewrite the selection via GPT, and replace it.
/// Mirrors DictationController; owns its own recorder so it never fights the
/// main dictation flow. @MainActor like the rest of the pipeline.
@MainActor
public final class VoiceEditController {
    public private(set) var state: VoiceEditState = .idle {
        didSet { onStateChange?(state) }
    }
    public var onStateChange: ((VoiceEditState) -> Void)?

    private let recorder: AudioRecording
    private let providers: () -> [TranscriptionProvider]
    private let store: RecordingStore
    private let hint: () -> TranscriptionHint
    private let readSelection: () -> String?
    private let rewrite: (String, String) async throws -> String
    private let replace: (String) -> Void
    private var capturedSelection: String?
    private var processingTask: Task<Void, Never>?

    public init(recorder: AudioRecording,
                providers: @escaping () -> [TranscriptionProvider],
                store: RecordingStore,
                hint: @escaping () -> TranscriptionHint,
                readSelection: @escaping () -> String?,
                rewrite: @escaping (String, String) async throws -> String,
                replace: @escaping (String) -> Void) {
        self.recorder = recorder
        self.providers = providers
        self.store = store
        self.hint = hint
        self.readSelection = readSelection
        self.rewrite = rewrite
        self.replace = replace
        self.recorder.onAutoStop = { [weak self] in
            DispatchQueue.main.async { self?.toggle() }
        }
    }

    public func toggle() {
        switch state {
        case .idle, .error:
            startRecording()
        case .recording:
            state = .rewriting
            processingTask = Task { await stopAndProcess() }
        case .rewriting:
            break
        }
    }

    public func toggleAndWait() async {
        toggle()
        await processingTask?.value
    }

    public func cancel() {
        guard state == .recording else { return }
        recorder.cancel()
        capturedSelection = nil
        state = .idle
    }

    private func startRecording() {
        guard let selection = readSelection(), !selection.isEmpty else {
            state = .error("Select some text first, then press the voice-edit key.")
            return
        }
        capturedSelection = selection
        let url = store.newRecordingURL()
        do {
            try recorder.start(to: url)
            state = .recording
        } catch {
            capturedSelection = nil
            state = .error("Couldn't start recording: \(error.localizedDescription)")
        }
    }

    private func stopAndProcess() async {
        let audioURL: URL
        do {
            audioURL = try recorder.stop()
        } catch {
            capturedSelection = nil
            state = .error("Couldn't stop recording: \(error.localizedDescription)")
            return
        }

        guard let selection = capturedSelection else {
            state = .error("Lost the selection. Try again.")
            return
        }
        capturedSelection = nil

        let chain = providers()
        guard !chain.isEmpty else {
            state = .error("No transcription provider configured. Open Settings.")
            return
        }

        var instruction: Transcript?
        for provider in chain {
            if let result = try? await provider.transcribe(audio: audioURL, hint: hint()) {
                instruction = result
                break
            }
        }
        guard let instruction, !instruction.text.isEmpty else {
            state = .error("Couldn't hear the instruction.")
            return
        }

        do {
            let edited = try await rewrite(selection, instruction.text)
            replace(edited)
            try? store.prune(keep: 10)
            state = .idle
        } catch {
            state = .error("Edit failed. Your text was not changed.")
        }
    }
}
