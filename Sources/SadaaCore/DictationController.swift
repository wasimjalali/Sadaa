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
    private let format: ((String, FormattingContext) async throws -> FormattingResult)?
    private let context: () -> FormattingContext
    private let suggestTerms: ([String]) -> Void
    private let formatterFellBack: () -> Void
    private let now: () -> Date
    private let isSecureInputActive: () -> Bool
    private var pendingRawMode = false
    private var processingTask: Task<Void, Never>?
    private var recordingStartedAt: Date?

    public init(recorder: AudioRecording,
                providers: @escaping () -> [TranscriptionProvider],
                store: RecordingStore,
                hint: @escaping () -> TranscriptionHint,
                recordingsToKeep: Int,
                deliver: @escaping (String) -> Void,
                record: @escaping (DictationRecord) -> Void = { _ in },
                format: ((String, FormattingContext) async throws -> FormattingResult)? = nil,
                context: @escaping () -> FormattingContext = {
                    FormattingContext(appBundleID: nil, dictionaryWords: [],
                                      speakerContext: "", language: .auto)
                },
                suggestTerms: @escaping ([String]) -> Void = { _ in },
                formatterFellBack: @escaping () -> Void = {},
                now: @escaping () -> Date = { Date() },
                isSecureInputActive: @escaping () -> Bool = { false }) {
        self.recorder = recorder
        self.providers = providers
        self.store = store
        self.hint = hint
        self.recordingsToKeep = recordingsToKeep
        self.deliver = deliver
        self.record = record
        self.format = format
        self.context = context
        self.suggestTerms = suggestTerms
        self.formatterFellBack = formatterFellBack
        self.now = now
        self.isSecureInputActive = isSecureInputActive
        self.recorder.onAutoStop = { [weak self] in
            DispatchQueue.main.async { self?.toggle() }
        }
    }

    /// Tap of the hotkey: start when idle, stop+process when recording.
    /// Ignored while a previous dictation is still processing.
    public func toggle(rawMode: Bool = false) {
        switch state {
        case .idle, .error:
            startRecording()
        case .recording:
            pendingRawMode = rawMode
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
        // A password field is focused: refuse rather than record and paste into
        // it. Spec section 5. IsSecureEventInputEnabled is injected from the app.
        guard !isSecureInputActive() else {
            state = .error("Secure field active. Dictation is off here.")
            return
        }
        let url = store.newRecordingURL()
        do {
            try recorder.start(to: url)
            recordingStartedAt = now()
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
        // Wall-clock recording length. The Azure json response carries no
        // duration, so this is the cost meter's only signal on the default path.
        let measuredDuration = recordingStartedAt.map { max(0, now().timeIntervalSince($0)) }

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

        // No speech in the whole recording: discard with a notice. Nothing is
        // formatted, recorded, or delivered (an empty deliver would also wipe the
        // clipboard). Spec section 5. The STT call was already billed by the API.
        guard !transcript.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            try? store.prune(keep: recordingsToKeep)
            state = .error("No speech detected.")
            return
        }

        // Raw transcript to the sidecar BEFORE formatting (never-lose).
        try? store.saveTranscript(transcript.text, for: audioURL)

        var finalText = transcript.text
        if !pendingRawMode, let format {
            do {
                let result = try await format(transcript.text, context())
                finalText = result.text
                if !result.newTerms.isEmpty { suggestTerms(result.newTerms) }
            } catch {
                formatterFellBack()   // keep raw finalText
            }
        }
        pendingRawMode = false

        record(DictationRecord(
            text: finalText,
            createdAt: Date(),
            language: transcript.detectedLanguage,
            provider: usedProvider ?? "unknown",
            durationSeconds: transcript.durationSeconds ?? measuredDuration))

        state = .delivering
        deliver(finalText)
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
