# Plan 3: OpenAI + MAI Providers, Fallback Chain, Cost Meter

> Implement task-by-task. Spec: `docs/superpowers/specs/2026-06-07-sadaa-design.md` (s3.3, s3.4, s3.5, s7). After each task `swift build` + `make test` green. Commit per task with Co-Authored-By trailer. No em dashes in user copy.

**Goal:** Ship the OpenAI fallback provider, the MAI/Azure-Speech provider (disabled by default), order them into a fallback chain, and add a credit-awareness cost meter.

**Architecture:** New providers mirror `AzureOpenAIProvider` (request builder + `transcribe` + `parse`, `URLProtocol`-stubbed tests). Cost is pure logic in `SadaaCore` (`CostEstimator`, `CostMeter`) plus an optional `estimatedCost` field on `DictationRecord`; the app computes cost in the `record` hook. Provider selection and rates live in `AppSettings`; the chain is assembled in `AppDelegate.buildProviders`.

---

### Task A: OpenAIProvider (SadaaCore, TDD)

**Files:** Create `Sources/SadaaCore/Transcription/OpenAIProvider.swift`; Test `Tests/SadaaCoreTests/OpenAIProviderTests.swift`.

Mirror `AzureOpenAIProvider` but: base `https://api.openai.com/v1/audio/transcriptions` (no query), `Authorization: Bearer {key}` header, multipart adds an explicit `model` field. Reuse `MultipartBody`, `ProviderError`, `AzureOpenAIProvider.withDeadline`, and a `parse` identical in shape (verbose_json). `name = "OpenAI"`.

```swift
import Foundation

/// OpenAI batch transcription fallback. Spec section 3.4.
public final class OpenAIProvider: TranscriptionProvider, @unchecked Sendable {
    public struct Config: Sendable {
        public let apiKey: String
        public let model: String   // e.g. "whisper-1" or "gpt-4o-transcribe"
        public init(apiKey: String, model: String) {
            self.apiKey = apiKey; self.model = model
        }
    }

    public let name = "OpenAI"
    private let config: Config
    private let session: URLSession
    private let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    public init(config: Config, session: URLSession = .shared) {
        self.config = config; self.session = session
    }

    public func makeRequest(audio: Data, filename: String,
                            hint: TranscriptionHint) throws -> URLRequest {
        var body = MultipartBody()
        body.addField(name: "model", value: config.model)
        body.addField(name: "response_format", value: "verbose_json")
        body.addField(name: "temperature", value: "0")
        if hint.languagePin != .auto {
            body.addField(name: "language", value: hint.languagePin.rawValue)
        }
        if !hint.dictionaryWords.isEmpty {
            body.addField(name: "prompt", value: hint.dictionaryWords.joined(separator: ", "))
        }
        body.addFile(name: "file", filename: filename, contentType: "audio/wav", data: audio)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body.encoded()
        request.timeoutInterval = 15
        return request
    }

    public func transcribe(audio: URL, hint: TranscriptionHint) async throws -> Transcript {
        let audioData = try Data(contentsOf: audio)
        let request = try makeRequest(audio: audioData, filename: audio.lastPathComponent, hint: hint)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await AzureOpenAIProvider.withDeadline(
                seconds: AzureOpenAIProvider.totalDeadline) { [session] in
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
        return try AzureOpenAIProvider.parse(data)
    }
}
```

Tests: request shape (URL == endpoint, `Authorization` == "Bearer test-key", body contains `name="model"\r\n\r\nwhisper-1`), pin+dictionary fields, success via stub, 401 throws. Use the existing `StubURLProtocol`. Commit: `feat: add OpenAIProvider transcription fallback`.

---

### Task B: AzureSpeechProvider / MAI (SadaaCore, TDD)

**Files:** Create `Sources/SadaaCore/Transcription/AzureSpeechProvider.swift`; Test `Tests/SadaaCoreTests/AzureSpeechProviderTests.swift`.

`POST {resourceEndpoint}/speechtotext/transcriptions:transcribe?api-version=2025-10-15`, header `Ocp-Apim-Subscription-Key`. Multipart: `audio` file + `definition` JSON field with `locales`, `phraseList.phrases` (dictionary words), `enhancedMode.{enabled,model}`. `name = "MAI"`. Parse: Azure Speech fast-transcription returns `combinedPhrases[0].text` and `duration` (ms) and per-phrase `locale`; decode defensively, fall back to `.badResponse`.

```swift
import Foundation

/// Azure Speech fast transcription (MAI-Transcribe). Spec section 3.3.
/// Ships behind a settings toggle; not in the default chain until enabled.
public final class AzureSpeechProvider: TranscriptionProvider, @unchecked Sendable {
    public struct Config: Sendable {
        public let endpoint: URL       // https://{res}.cognitiveservices.azure.com
        public let apiKey: String
        public let apiVersion: String  // default "2025-10-15"
        public let model: String       // "mai-transcribe-1.5"
        public init(endpoint: URL, apiKey: String,
                    apiVersion: String = "2025-10-15", model: String = "mai-transcribe-1.5") {
            self.endpoint = endpoint; self.apiKey = apiKey
            self.apiVersion = apiVersion; self.model = model
        }
    }

    public let name = "MAI"
    private let config: Config
    private let session: URLSession

    public init(config: Config, session: URLSession = .shared) {
        self.config = config; self.session = session
    }

    public func makeRequest(audio: Data, filename: String,
                            hint: TranscriptionHint) throws -> URLRequest {
        var components = URLComponents(
            url: config.endpoint.appendingPathComponent("speechtotext/transcriptions:transcribe"),
            resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "api-version", value: config.apiVersion)]

        let locales: [String]
        switch hint.languagePin {
        case .en: locales = ["en-US"]
        case .de: locales = ["de-DE"]
        case .auto: locales = ["en-US", "de-DE"]
        }
        let definition: [String: Any] = [
            "locales": locales,
            "phraseList": ["phrases": hint.dictionaryWords],
            "enhancedMode": ["enabled": true, "model": config.model],
        ]
        let definitionData = try JSONSerialization.data(withJSONObject: definition)

        var body = MultipartBody()
        body.addField(name: "definition", value: String(decoding: definitionData, as: UTF8.self))
        body.addFile(name: "audio", filename: filename, contentType: "audio/wav", data: audio)

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(config.apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body.encoded()
        request.timeoutInterval = 15
        return request
    }

    public func transcribe(audio: URL, hint: TranscriptionHint) async throws -> Transcript {
        let audioData = try Data(contentsOf: audio)
        let request = try makeRequest(audio: audioData, filename: audio.lastPathComponent, hint: hint)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await AzureOpenAIProvider.withDeadline(
                seconds: AzureOpenAIProvider.totalDeadline) { [session] in
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
        struct Fast: Decodable {
            struct Phrase: Decodable { let text: String?; let locale: String? }
            let combinedPhrases: [Phrase]?
            let durationMilliseconds: Double?
        }
        guard let decoded = try? JSONDecoder().decode(Fast.self, from: data),
              let text = decoded.combinedPhrases?.first?.text else {
            throw ProviderError.badResponse
        }
        return Transcript(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            detectedLanguage: decoded.combinedPhrases?.first?.locale,
            durationSeconds: decoded.durationMilliseconds.map { $0 / 1000 })
    }
}
```

Tests: request shape (URL path + api-version query, `Ocp-Apim-Subscription-Key` header, `definition` field JSON contains phraseList with dictionary words, auto pin yields both locales), parse `combinedPhrases`+`durationMilliseconds`->seconds, missing combinedPhrases throws `.badResponse`. Commit: `feat: add AzureSpeechProvider (MAI) behind a settings toggle`.

---

### Task C: Cost meter (SadaaCore, TDD)

**Files:** Modify `Sources/SadaaCore/History/DictationRecord.swift`; Create `Sources/SadaaCore/Cost/CostEstimator.swift`, `Sources/SadaaCore/Cost/CostMeter.swift`; Test `Tests/SadaaCoreTests/CostTests.swift`. Touch `Tests/SadaaCoreTests/DictationHistoryTests.swift` only if a record literal needs the new param (it has a default, so no change required).

DictationRecord: add `public let estimatedCost: Double?` with init default `nil` (Codable: old JSON without the key decodes to nil). Add:
```swift
    public func withEstimatedCost(_ cost: Double?) -> DictationRecord {
        DictationRecord(id: id, text: text, createdAt: createdAt, language: language,
                        provider: provider, durationSeconds: durationSeconds,
                        estimatedCost: cost)
    }
```
(init becomes `..., durationSeconds: Double?, estimatedCost: Double? = nil`.)

`CostEstimator` (pure): estimated dollars = transcription (duration-based) + formatter (character-based).
```swift
import Foundation

public enum CostEstimator {
    /// Credit-awareness estimate, not accounting. Spec section 7.
    public static func estimate(durationSeconds: Double?,
                                transcriptionRatePerMinute: Double,
                                characters: Int,
                                formatterRatePer1kChars: Double) -> Double {
        let minutes = (durationSeconds ?? 0) / 60
        let transcription = minutes * transcriptionRatePerMinute
        let formatter = Double(characters) / 1000 * formatterRatePer1kChars
        return transcription + formatter
    }
}
```

`CostMeter` (pure aggregation):
```swift
import Foundation

public enum CostMeter {
    public struct Totals: Equatable, Sendable {
        public let minutes: Double
        public let cost: Double
    }

    /// Sums minutes and estimated cost for records in `now`'s month.
    public static func monthlyTotals(records: [DictationRecord], now: Date,
                                     calendar: Calendar = .current) -> Totals {
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        var minutes = 0.0, cost = 0.0
        for r in records {
            guard calendar.component(.month, from: r.createdAt) == month,
                  calendar.component(.year, from: r.createdAt) == year else { continue }
            minutes += (r.durationSeconds ?? 0) / 60
            cost += r.estimatedCost ?? 0
        }
        return Totals(minutes: minutes, cost: cost)
    }
}
```

Tests: estimator math (duration + char terms), zero-duration handles nil, monthly totals filter by month/year (two records, one last month excluded), withEstimatedCost copies all fields, DictationRecord Codable round-trip with cost. Commit: `feat: add cost estimator and monthly cost meter`.

---

### Task D: Settings (providers + rates), provider chain, cost UI, deploy (SadaaApp)

**Files:** Modify `Sources/SadaaCore/Settings/AppSettings.swift`, `Sources/SadaaApp/AppDelegate.swift`, `Sources/SadaaApp/Pages/SettingsPage.swift`, `Sources/SadaaApp/SadaaViewModel.swift`, `Sources/SadaaApp/Pages/HistoryPage.swift`.

1. AppSettings new keys/accessors: `openaiEnabled: Bool` (default false), `openaiModel: String` (default "whisper-1"), `maiEnabled: Bool` (default false), `maiEndpoint: String`, `maiApiVersion: String` (default "2025-10-15"), `maiModel: String` (default "mai-transcribe-1.5"), `transcriptionRatePerMinute: Double` (default 0.006), `formatterRatePer1kChars: Double` (default 0.002). Keychain accounts: `openai-key`, `azure-speech-key`.

2. `AppDelegate.buildProviders`: assemble the chain in order: Azure OpenAI (if configured), then OpenAI (if `openaiEnabled` + key), then MAI (if `maiEnabled` + endpoint + key). Return all that are configured. (Each built like the existing Azure builder.)

3. `record` hook: compute cost and append a costed record, then refresh recent + cost:
```swift
            record: { [weak self] record in
                guard let self else { return }
                let cost = CostEstimator.estimate(
                    durationSeconds: record.durationSeconds,
                    transcriptionRatePerMinute: self.settings.transcriptionRatePerMinute,
                    characters: record.text.count,
                    formatterRatePer1kChars: self.settings.formatterRatePer1kChars)
                self.history?.append(record.withEstimatedCost(cost))
                self.viewModel?.refreshRecent()
                self.viewModel?.refreshCost()
            }
```

4. `SadaaViewModel`: `@Published var monthlyCost = CostMeter.Totals(minutes: 0, cost: 0)`; `func refreshCost() { monthlyCost = CostMeter.monthlyTotals(records: history.all(), now: Date()) }`; call it in init. (Use the real `Date()`; this is app code, not a test.)

5. SettingsPage: add a "Providers" section (OpenAI toggle + model + key SecureField; MAI toggle + endpoint + key SecureField) and a "Cost" section (two `TextField`s bound to the rates via numeric formatting, plus a line showing `viewModel.monthlyCost` minutes and dollars). Load/save the new fields and Keychain accounts alongside the Azure ones.

6. HistoryPage: show each row's `estimatedCost` (when present) as a small tag, and a header line with this month's total from `viewModel.monthlyCost`.

7. `swift build -c release` clean, `make test` green, `make bundle && make install`. Smoke: configure OpenAI key, break Azure key, confirm fallback serves the request and History shows provider "OpenAI"; confirm cost line increments; toggle MAI on with endpoint+key and confirm it appears last in the chain. Commit: `feat: add OpenAI/MAI provider chain, rates and cost meter to the app`.

---

## Self-review
- Spec coverage: OpenAI s3.4 (A), MAI s3.3 (B), fallback chain s3.5 (D2), cost meter s7 (C, D3-6). History panel already shipped in the main-window work.
- `estimatedCost` default keeps old history.json decodable and existing `DictationHistory`/controller tests green.
- Provider `parse` reuse: OpenAI reuses `AzureOpenAIProvider.parse` (same verbose_json); MAI has its own.
- Out of scope (Plan 4): snippets, voice-edit, notes, onboarding, launch-at-login.
