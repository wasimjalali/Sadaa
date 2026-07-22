# Deepgram Nova-3 + Simplified Settings Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax. Swift compiles the whole module at once, so tasks are ordered and sized so each one ends with a compiling build and green tests. TDD is used for the new provider; the refactor/deletion tasks verify with `make test`.

**Goal:** Replace Sadaa's Azure/OpenAI speech-to-text and GPT features with Deepgram Nova-3, store the Deepgram key in the Keychain, and simplify the Settings UI.

**Architecture:** A single `DeepgramProvider` behind the existing `TranscriptionProvider` protocol. The GPT formatter and Voice Edit are removed; Deepgram's `smart_format` handles cleanup, and the local Language Memory corrections stay. The cost meter is removed entirely.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, Swift Package Manager, macOS 14+, swift-testing (`Testing`).

## Global Constraints

- Package manager: Swift Package Manager only. Build `make build`, test `make test`, install `make install`.
- Voice: no em dashes in any user-facing string; contractions; no Oxford comma in UI copy.
- Secrets: never in UserDefaults. Deepgram key lives in Keychain, service `ai.karko.sadaa`, account `deepgram-key`.
- `swift build` clean and `swift test` green is the definition of done for code tasks.

---

### Task 1: DeepgramProvider (new, isolated)

**Files:**
- Create: `Sources/SadaaCore/Transcription/DeepgramProvider.swift`
- Test: `Tests/SadaaCoreTests/DeepgramProviderTests.swift`

**Interfaces:**
- Consumes: `TranscriptionProvider`, `TranscriptionHint`, `Transcript`, `ProviderError`, `LanguagePin`.
- Produces: `DeepgramProvider(config: DeepgramProvider.Config(apiKey:model:smartFormat:), session:)`, `name == "Deepgram"`, `makeRequest(audio:hint:) throws -> URLRequest`, `transcribe(audio:hint:) async throws -> Transcript`, statics `baseURL`, `languageParameter(for:)`, `totalDeadline`, `withDeadline(seconds:_:)`, `parse(_:)`.

- [ ] **Step 1: Write DeepgramProvider**

```swift
import Foundation

/// Deepgram Nova-3 pre-recorded transcription.
/// POST https://api.deepgram.com/v1/listen with the raw WAV bytes as the body.
/// @unchecked Sendable: no mutable state; both stored properties are Sendable.
public final class DeepgramProvider: TranscriptionProvider, @unchecked Sendable {
    public struct Config: Sendable {
        public let apiKey: String
        public let model: String
        public let smartFormat: Bool

        public init(apiKey: String, model: String = "nova-3", smartFormat: Bool) {
            self.apiKey = apiKey
            self.model = model
            self.smartFormat = smartFormat
        }
    }

    public let name = "Deepgram"
    private let config: Config
    private let session: URLSession

    public init(config: Config, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    static let baseURL = URL(string: "https://api.deepgram.com/v1/listen")!

    /// Wall-clock deadline for one attempt (matches the old provider chain).
    static let totalDeadline: TimeInterval = 15

    /// Nova-3 language codes. Auto-detect maps to `multi` (multilingual
    /// code-switching, Nova-3 only).
    static func languageParameter(for pin: LanguagePin) -> String {
        switch pin {
        case .en: return "en"
        case .de: return "de"
        case .auto: return "multi"
        }
    }

    public func makeRequest(audio: Data, hint: TranscriptionHint) throws -> URLRequest {
        let apiKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw ProviderError.notConfigured("Enter your Deepgram API key.")
        }
        var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "model", value: config.model),
            URLQueryItem(name: "language", value: Self.languageParameter(for: hint.languagePin)),
        ]
        if config.smartFormat {
            items.append(URLQueryItem(name: "smart_format", value: "true"))
        }
        // Nova-3 keyterm prompting biases recognition toward the user's
        // vocabulary. Repeated once per term.
        for term in hint.dictionaryWords {
            items.append(URLQueryItem(name: "keyterm", value: term))
        }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = audio
        request.timeoutInterval = Self.totalDeadline
        return request
    }

    /// Races work against a true wall-clock deadline (timeoutInterval is only an
    /// idle timeout, so a slow trickling upload can exceed it indefinitely).
    static func withDeadline<T: Sendable>(
        seconds: TimeInterval,
        _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ProviderError.timedOut
            }
            guard let result = try await group.next() else {
                throw ProviderError.timedOut
            }
            group.cancelAll()
            return result
        }
    }

    public func transcribe(audio: URL, hint: TranscriptionHint) async throws -> Transcript {
        let request = try makeRequest(audio: Data(contentsOf: audio), hint: hint)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Self.withDeadline(seconds: Self.totalDeadline) { [session] in
                try await session.data(for: request)
            }
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw ProviderError.timedOut
        } catch let urlError as URLError {
            throw ProviderError.transport(urlError)
        }
        guard let http = response as? HTTPURLResponse else { throw ProviderError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw ProviderError.http(http.statusCode, String(decoding: data, as: UTF8.self))
        }
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> Transcript {
        struct Response: Decodable {
            struct Metadata: Decodable { let duration: Double? }
            struct Results: Decodable {
                struct Channel: Decodable {
                    struct Alternative: Decodable { let transcript: String }
                    let alternatives: [Alternative]
                }
                let channels: [Channel]
            }
            let metadata: Metadata?
            let results: Results
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let transcript = decoded.results.channels.first?.alternatives.first?.transcript else {
            throw ProviderError.badResponse
        }
        return Transcript(
            text: transcript.trimmingCharacters(in: .whitespacesAndNewlines),
            detectedLanguage: nil,
            durationSeconds: decoded.metadata?.duration)
    }
}
```

- [ ] **Step 2: Write DeepgramProviderTests**

```swift
import Testing
import Foundation
@testable import SadaaCore

@Suite(.serialized) struct DeepgramProviderTests {
    private func provider(
        apiKey: String = "test-key",
        smartFormat: Bool = true,
        session: URLSession = .shared
    ) -> DeepgramProvider {
        DeepgramProvider(
            config: .init(apiKey: apiKey, smartFormat: smartFormat),
            session: session
        )
    }

    @Test func testRequestShapeUsesListenEndpointWithNova3() throws {
        let request = try provider().makeRequest(
            audio: Data([0x52, 0x49, 0x46, 0x46]),
            hint: TranscriptionHint(languagePin: .de, dictionaryWords: ["Sadaa", "Claude Code"])
        )
        let query = request.url?.query ?? ""
        #expect(request.url?.host == "api.deepgram.com")
        #expect(request.url?.path == "/v1/listen")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Token test-key")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "audio/wav")
        #expect(query.contains("model=nova-3"))
        #expect(query.contains("language=de"))
        #expect(query.contains("smart_format=true"))
        #expect(query.contains("keyterm=Sadaa"))
        #expect(query.contains("keyterm=Claude%20Code"))
        #expect(request.httpBody == Data([0x52, 0x49, 0x46, 0x46]))
    }

    @Test func testAutoLanguageMapsToMultiAndSmartFormatOffOmitsParam() throws {
        let request = try provider(smartFormat: false).makeRequest(
            audio: Data([0x01]),
            hint: TranscriptionHint(languagePin: .auto, dictionaryWords: [])
        )
        let query = request.url?.query ?? ""
        #expect(query.contains("language=multi"))
        #expect(!query.contains("smart_format"))
        #expect(!query.contains("keyterm"))
    }

    @Test func testMissingKeyThrows() {
        #expect(throws: ProviderError.self) {
            try provider(apiKey: "   ").makeRequest(
                audio: Data([0x01]),
                hint: TranscriptionHint(languagePin: .auto, dictionaryWords: [])
            )
        }
    }

    @Test func testTranscribeParsesDeepgramJSON() async throws {
        DeepgramStubURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Token test-key")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = #"{"metadata":{"duration":1.5},"results":{"channels":[{"alternatives":[{"transcript":"  hello from Sadaa  "}]}]}}"#
            return (response, Data(json.utf8))
        }
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("deepgram-\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let transcript = try await provider(session: DeepgramStubURLProtocol.session()).transcribe(
            audio: audioURL,
            hint: TranscriptionHint(languagePin: .auto, dictionaryWords: [])
        )
        #expect(transcript.text == "hello from Sadaa")
        #expect(transcript.durationSeconds == 1.5)
        #expect(transcript.detectedLanguage == nil)
    }
}

private final class DeepgramStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DeepgramStubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else { return }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
```

- [ ] **Step 3: Run tests, expect green.** `make test` (all suites, including the new one).
- [ ] **Step 4: Commit.** `feat: add Deepgram Nova-3 transcription provider`

---

### Task 2: Rewire the app layer to Deepgram-only

Keep `AppSettings` fields for now (unused ones are harmless), so the module still compiles. This task makes the running app use Deepgram, drops the GPT formatter path and cost from the app layer, and rewrites Settings.

**Files:**
- Modify: `Sources/SadaaApp/AppDelegate.swift`
- Modify: `Sources/SadaaApp/SadaaViewModel.swift`
- Modify: `Sources/SadaaApp/Pages/SettingsPage.swift`
- Modify: `Sources/SadaaApp/Pages/HistoryPage.swift`
- Modify: `Sources/SadaaApp/Pages/HomePage.swift`

- [ ] **AppDelegate.buildProviders:** replace the `switch settings.speechProviderKind` body with:

```swift
private static func buildProviders(settings: AppSettings) -> [TranscriptionProvider] {
    guard let key = Keychain.get(account: "deepgram-key"), !key.isEmpty else { return [] }
    return [DeepgramProvider(config: .init(apiKey: key, smartFormat: settings.formattingEnabled))]
}
```

- [ ] **AppDelegate: delete `buildFormatter`, `describeFormatterError`.** Simplify the `format:` closure passed to `DictationController` to drop the GPT branch (keep the local Language Memory step):

```swift
format: { [languageMemory] raw, ctx in
    let memory = languageMemory.snapshot()
    let memoryLanguage = MemoryLanguage(languagePin: ctx.language)
    let prepared = LanguageMemoryPostProcessor.applyDeterministic(
        to: raw, snapshot: memory, language: memoryLanguage)
    return LanguageMemoryPostProcessor.rawResult(from: prepared)
},
```

- [ ] **AppDelegate: remove cost.** In the `record:` closure delete the `CostEstimator.estimate(...)` block and store the record directly (`self.history?.append(record)` instead of `withEstimatedCost`). In `reprocessHistory` (around line 370-381) delete the `CostEstimator.estimate` call and append `reprocessed` directly. Remove the `formatterUnavailable:` closure argument and the `pendingDeliveryNotice` formatter-unavailable strings tied to the GPT formatter. Remove the `speakerContext:` argument from the `context:` closure's `FormattingContext(...)`.

- [ ] **SadaaViewModel:** change the default `providerName` to `"Deepgram"`. Replace the `refreshConfig()` provider `switch` with:

```swift
providerName = "Deepgram"
providerConfigured = Keychain.exists(account: "deepgram-key")
```

Delete the `@Published var monthlyCost` property, the `refreshCost()` method, and its call in `init`/anywhere it is invoked.

- [ ] **SettingsPage rewrite:** remove all Azure/compatible state (`providerKind`, `azureEndpoint`, `azureDeployment`, `azureAPIVersion`, `azureKey`, `compatibleEndpoint`, `compatibleModel`, `compatibleKey`, `hasAzureKey`, `hasCompatibleKey`, `gptDeployment`, `speakerContext`, `transcriptionRate`, `formatterRate`). Add `@State private var deepgramKey = ""` and `@State private var hasDeepgramKey = false`. Replace `speechSection` with a Deepgram section: the single masked key field (placeholder `Enter your Deepgram API key`, "Stored in Keychain" + Remove button via the existing `secretField`, clearing `Keychain.delete(account: "deepgram-key")`) plus the `formattingEnabled` toggle labelled "Auto-format transcript" with detail "Adds punctuation, capitalization and formatted numbers". Delete `writingSection` entirely. In `dataSection` remove the two rate `field`s and the "This month" cost row, keeping only "Stop after silence" and "Keep recordings". Update `load()`, `save()` (write `deepgramKey` to `deepgram-key`), and `testConnection()` (build a `DeepgramProvider` from the saved/typed key and `formattingEnabled`). Update the section header copy to remove "Azure OpenAI".

- [ ] **HistoryPage:** delete the line `if let cost = record.estimatedCost { detailLine("Estimated cost", PageFormat.dollars(cost)) }`.

- [ ] **HomePage:** delete `static func minutes` and `static func dollars` from `PageFormat` (now unused).

- [ ] **Verify + commit.** `make test` green, `make build` clean. Commit: `feat: switch speech-to-text to Deepgram and simplify settings`.

---

### Task 3: Delete dead Azure/GPT/cost code and trim settings

Now that nothing references them, delete the dead types and trim the model.

**Files:**
- Delete: `Sources/SadaaCore/Transcription/AzureOpenAIProvider.swift`, `OpenAICompatibleProvider.swift`, `MultipartBody.swift`
- Delete: `Sources/SadaaCore/Formatting/AzureChatFormatter.swift`, `FormattingPromptBuilder.swift`, `FormattingProfile.swift`
- Delete: `Sources/SadaaCore/ProviderHealth/FormatterHealthCheck.swift`
- Delete: `Sources/SadaaCore/VoiceEdit/VoiceEditController.swift`, `VoiceEditPromptBuilder.swift`
- Delete: `Sources/SadaaCore/Cost/CostMeter.swift`, `CostEstimator.swift`
- Delete tests: `AzureOpenAIProviderTests.swift`, `OpenAICompatibleProviderTests.swift`, `MultipartBodyTests.swift`, `AzureChatFormatterTests.swift`, `AzureChatFormatterTests`? (also `AzureChatFormatterTests.swift`), `FormattingPromptBuilderTests.swift`, `FormattingProfileTests.swift`, `VoiceEditTests.swift`, `VoiceEditPromptBuilderTests.swift`, `CostTests.swift`
- Modify: `Sources/SadaaCore/Settings/AppSettings.swift`, `Sources/SadaaCore/Formatting/FormattingContext.swift`, `Sources/SadaaCore/History/DictationRecord.swift`
- Modify tests: `AppSettingsTests.swift`, `DictationHistoryTests.swift`, `DictationControllerTests.swift`, `ProviderHealthCheckTests.swift`, `SnippetStoreTests.swift` (only where they reference removed symbols)

- [ ] **AppSettings:** remove keys and accessors for `speechProviderKind`, `azureEndpoint`, `azureDeployment`, `transcriptionPreset`, `fastTranscriptionDeployment`, `accurateTranscriptionDeployment`, `azureAPIVersion`, `compatibleEndpoint`, `compatibleModel`, `gptDeployment`, `speakerContext`, `transcriptionRatePerMinute`, `formatterRatePer1kChars`. Delete the `SpeechProviderKind` and `TranscriptionPreset` enums. Keep `formattingEnabled` (now the auto-format switch), `languagePin`, `silenceTimeout`, `recordingsToKeep`, `hotkeyKeycode`, `languageSwitchKeycode`, `soundEffectsEnabled`, `lastExportFolder`.

- [ ] **FormattingContext:** remove the `speakerContext` property and its init parameter. Update the two remaining construction sites (DictationController's default `context` param at lines ~61-64, already handled if Task 2 dropped it — otherwise drop it here) and any test that passes `speakerContext:`.

- [ ] **DictationRecord:** remove the `estimatedCost` property, its init parameter, and the `withEstimatedCost(_:)` method. (Old history JSON with the extra `estimatedCost` key still decodes fine.)

- [ ] **Fix test references:** in `DictationHistoryTests` remove the `withEstimatedCost` usage; in any test constructing `FormattingContext(... speakerContext: ...)` drop that argument; delete the whole test files listed above.

- [ ] **Verify + commit.** `make test` green (full suite), `make build` clean. Commit: `refactor: remove Azure OpenAI, GPT formatter, Voice Edit and cost meter`.

---

### Task 4: Build, install, launch for live testing

- [ ] **Step 1: Release build.** `make build` (expect clean).
- [ ] **Step 2: Full test suite.** `make test` (expect all green).
- [ ] **Step 3: Install + launch.** `make install` (bundles, copies to `/Applications/Sadaa.app`, relaunches).
- [ ] **Step 4: Report to user** that the app is installed and open, with a short test checklist (enter Deepgram key, dictate, confirm auto-format, toggle it off for raw, switch language).

---

## Self-Review

**Spec coverage:** Deepgram provider (Task 1), STT swap + settings simplification + auto-format toggle + data section trim (Task 2), Azure/GPT/Voice Edit/cost removal + AppSettings trim (Tasks 2-3), Keychain `deepgram-key` (Task 2), build+install (Task 4). All spec sections map to a task.

**Placeholder scan:** No TBD/TODO; the one "similar to" is avoided by listing exact symbols. `MultipartBody` removal is conditional in the spec but decided here (Deepgram uses a raw body, so it is deleted).

**Type consistency:** `DeepgramProvider.Config(apiKey:model:smartFormat:)`, `formattingEnabled` drives `smartFormat`, `name == "Deepgram"`, Keychain account `deepgram-key`, and `languageParameter(for:)` mapping are used consistently across tasks.
