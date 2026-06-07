import Foundation

public enum DictationState: Equatable, Sendable {
    case idle
    case recording
    case transcribing
    case delivering
    case error(String)
}

/// The dictation pipeline state machine. Spec section 4 data flow and
/// section 5 error rules. UI-agnostic: state changes surface via callback.
@MainActor
public final class DictationController {
    public private(set) var state: DictationState = .idle {
        didSet { onStateChange?(state) }
    }
    public var onStateChange: ((DictationState) -> Void)?

    private let recorder: AudioRecording
    private let providers: () -> [TranscriptionProvider]
    private let store: RecordingStore
    private let hint: () -> TranscriptionHint
    private let recordingsToKeep: Int
    private let deliver: (String) -> Void
    private let record: (DictationRecord) -> Void
    private var processingTask: Task<Void, Never>?

    public init(recorder: AudioRecording,
                providers: @escaping () -> [TranscriptionProvider],
                store: RecordingStore,
                hint: @escaping () -> TranscriptionHint,
                recordingsToKeep: Int,
                deliver: @escaping (String) -> Void,
                record: @escaping (DictationRecord) -> Void = { _ in }) {
        self.recorder = recorder
        self.providers = providers
        self.store = store
        self.hint = hint
        self.recordingsToKeep = recordingsToKeep
        self.deliver = deliver
        self.record = record
        self.recorder.onAutoStop = { [weak self] in
            DispatchQueue.main.async { self?.toggle() }
        }
    }

    /// Tap of the hotkey: start when idle, stop+process when recording.
    /// Ignored while a previous dictation is still processing.
    public func toggle() {
        switch state {
        case .idle, .error:
            startRecording()
        case .recording:
            state = .transcribing   // synchronous: a racing toggle now sees .transcribing and is ignored
            processingTask = Task { await stopAndProcess() }
        case .transcribing, .delivering:
            break // busy; ignore to avoid double-processing
        }
    }

    /// Test helper / programmatic variant that awaits the processing.
    public func toggleAndWait() async {
        toggle()
        await processingTask?.value
    }

    public func cancel() {
        guard state == .recording else { return }
        recorder.cancel()
        state = .idle
    }

    private func startRecording() {
        let url = store.newRecordingURL()
        do {
            try recorder.start(to: url)
            state = .recording
        } catch {
            state = .error("Couldn't start recording: \(error.localizedDescription)")
        }
    }

    private func stopAndProcess() async {
        let audioURL: URL
        do {
            audioURL = try recorder.stop()
        } catch {
            state = .error("Couldn't stop recording: \(error.localizedDescription)")
            return
        }

        // state is already .transcribing (set synchronously in toggle())
        let chain = providers()
        guard !chain.isEmpty else {
            state = .error("No transcription provider configured. Open Settings.")
            return
        }

        var transcript: Transcript?
        var usedProvider: String?
        var lastError: Error?
        for provider in chain {
            do {
                transcript = try await provider.transcribe(audio: audioURL,
                                                            hint: hint())
                usedProvider = provider.name
                break
            } catch {
                lastError = error
            }
        }

        guard let transcript else {
            let detail = (lastError as? ProviderError).map(Self.describe)
                ?? lastError?.localizedDescription ?? "unknown error"
            state = .error("Transcription failed: \(detail)")
            return
        }

        try? store.saveTranscript(transcript.text, for: audioURL)

        record(DictationRecord(
            text: transcript.text,
            createdAt: Date(),
            language: transcript.detectedLanguage,
            provider: usedProvider ?? "unknown",
            durationSeconds: transcript.durationSeconds))

        state = .delivering
        deliver(transcript.text)
        try? store.prune(keep: recordingsToKeep)
        state = .idle
    }

    private static func describe(_ error: ProviderError) -> String {
        switch error {
        case .http(let status, _): return "HTTP \(status) from provider"
        case .badResponse: return "unreadable provider response"
        case .notConfigured(let what): return what
        case .timedOut: return "timed out"
        case .transport(let urlError): return urlError.localizedDescription
        }
    }
}
