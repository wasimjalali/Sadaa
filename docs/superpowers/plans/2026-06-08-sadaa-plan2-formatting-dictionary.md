# Plan 2: Smart Formatting + Per-App Profiles + Dictionary Implementation Plan

> **For agentic workers:** Implement task-by-task. Steps use checkbox (`- [ ]`) syntax. Spec: `docs/superpowers/specs/2026-06-07-sadaa-design.md` (sections 3.6, 4 formatting/dictionary, 5, 8). After each task `swift build` and `make test` must be green. Commit per task (conventional commits, Co-Authored-By trailer). No em dashes in user-facing copy.

**Goal:** Add a smart-formatting pass (Azure GPT chat completion, app-aware profiles, raw-mode skip) and a working dictionary (manual entries that bias recognition, plus a formatter-driven auto-suggest loop) to the existing dictation pipeline.

**Architecture:** All testable logic lands in `SadaaCore` (Swift Testing, `URLProtocol` stubs for network) following the existing `AzureOpenAIProvider`/`DictationHistory` patterns. The `DictationController` gains optional, defaulted hooks (`format`, `context`, `suggestTerms`, `formatterFellBack`, `rawMode`) so all existing tests stay green. `SadaaApp` wires the formatter and dictionary in `AppDelegate` and grows two UI surfaces (Settings formatting section, real Dictionary page). UI glue is live-verified, not unit-tested, matching the repo convention.

**Tech Stack:** Swift 5.9 / SwiftUI / AppKit, SPM, Swift Testing via `make test`. Azure OpenAI chat completions. Codable JSON stores (no SwiftData).

---

### Task A: FormattingContext + FormattingResult + Profiles + prompt builder (SadaaCore, TDD)

**Files:**
- Create: `Sources/SadaaCore/Formatting/FormattingContext.swift`
- Create: `Sources/SadaaCore/Formatting/FormattingProfile.swift`
- Create: `Sources/SadaaCore/Formatting/FormattingPromptBuilder.swift`
- Test: `Tests/SadaaCoreTests/FormattingProfileTests.swift`
- Test: `Tests/SadaaCoreTests/FormattingPromptBuilderTests.swift`

- [ ] **Step 1: Write the value types**

`FormattingContext.swift`:
```swift
import Foundation

/// Everything the formatter needs about one dictation besides the raw text.
public struct FormattingContext: Sendable {
    public let appBundleID: String?
    public let dictionaryWords: [String]
    public let speakerContext: String
    public let language: LanguagePin

    public init(appBundleID: String?,
                dictionaryWords: [String],
                speakerContext: String,
                language: LanguagePin) {
        self.appBundleID = appBundleID
        self.dictionaryWords = dictionaryWords
        self.speakerContext = speakerContext
        self.language = language
    }
}

/// What the formatter returns: polished text plus up to a few newly guessed terms.
public struct FormattingResult: Equatable, Sendable {
    public let text: String
    public let newTerms: [String]

    public init(text: String, newTerms: [String]) {
        self.text = text
        self.newTerms = newTerms
    }
}
```

- [ ] **Step 2: Write the profiles**

`FormattingProfile.swift`:
```swift
import Foundation

/// A named system-prompt fragment plus the app bundle ids it applies to. Spec
/// section 4 "Formatting profiles".
public struct FormattingProfile: Equatable, Sendable {
    public let name: String
    public let bundleIDs: [String]
    public let promptFragment: String

    public init(name: String, bundleIDs: [String], promptFragment: String) {
        self.name = name
        self.bundleIDs = bundleIDs
        self.promptFragment = promptFragment
    }
}

public enum FormattingProfiles {
    public static let code = FormattingProfile(
        name: "Prompt/code",
        bundleIDs: [
            "com.todesktop.230313mzl4w4u92", // Cursor
            "com.microsoft.VSCode",
            "com.apple.Terminal",
            "dev.warp.Warp-Stable",
            "com.googlecode.iterm2",
        ],
        promptFragment: "The target app is a code editor or terminal. Keep technical terms, identifiers, camelCase and snake_case exactly. No greetings, no filler, no sign-offs. Plain imperative sentences.")

    public static let chat = FormattingProfile(
        name: "Chat",
        bundleIDs: [
            "com.tinyspeck.slackmacgap",   // Slack
            "com.hnc.Discord",
            "net.whatsapp.WhatsApp",
            "ru.keepcoder.Telegram",
        ],
        promptFragment: "The target app is a casual chat. Keep it conversational and short, use contractions, drop heavy punctuation.")

    public static let mail = FormattingProfile(
        name: "Mail/docs",
        bundleIDs: [
            "com.apple.mail",
            "com.apple.iWork.Pages",
            "com.microsoft.Outlook",
        ],
        promptFragment: "The target app is email or a document. Use full sentences, proper punctuation and capitalization.")

    public static let `default` = FormattingProfile(
        name: "Default",
        bundleIDs: [],
        promptFragment: "Light cleanup, neutral tone.")

    /// Profiles with explicit bundle ids, checked in order.
    public static let all = [code, chat, mail]

    /// Maps a frontmost app bundle id to its profile, falling back to `default`.
    public static func resolve(bundleID: String?) -> FormattingProfile {
        guard let bundleID else { return .default }
        for profile in all where profile.bundleIDs.contains(bundleID) {
            return profile
        }
        return .default
    }
}
```

- [ ] **Step 3: Write the prompt builder**

`FormattingPromptBuilder.swift`:
```swift
import Foundation

/// Assembles the formatter system prompt from a profile, the speaker context,
/// and the dictionary. Pure and testable. Spec section 4.
public enum FormattingPromptBuilder {
    public static func systemPrompt(profile: FormattingProfile,
                                    dictionaryWords: [String],
                                    speakerContext: String) -> String {
        var lines: [String] = []
        lines.append("You clean up dictated speech into polished written text.")
        lines.append(speakerContext)
        lines.append(profile.promptFragment)
        lines.append("Always: remove filler words, fix punctuation and casing, apply mid-sentence self-corrections (\"at 2, actually 3\" becomes \"at 3\"), format spoken lists, and reply in the same language as the input (German stays German).")
        if !dictionaryWords.isEmpty {
            lines.append("Enforce these exact spellings when they occur: \(dictionaryWords.joined(separator: ", ")).")
        }
        lines.append("Respond ONLY with a JSON object of the form {\"text\": \"<the formatted text>\", \"newTerms\": [\"<unusual proper noun or jargon you had to guess>\"]}. newTerms holds at most 3 entries and is [] when there is nothing unusual. Do not wrap the JSON in markdown.")
        return lines.joined(separator: "\n")
    }
}
```

- [ ] **Step 4: Write the failing tests**

`FormattingProfileTests.swift`:
```swift
import Testing
@testable import SadaaCore

@Suite struct FormattingProfileTests {
    @Test func testResolvesCodeProfile() {
        let p = FormattingProfiles.resolve(bundleID: "com.microsoft.VSCode")
        #expect(p.name == "Prompt/code")
    }

    @Test func testResolvesChatProfile() {
        let p = FormattingProfiles.resolve(bundleID: "com.tinyspeck.slackmacgap")
        #expect(p.name == "Chat")
    }

    @Test func testUnknownBundleFallsBackToDefault() {
        #expect(FormattingProfiles.resolve(bundleID: "com.unknown.app").name == "Default")
    }

    @Test func testNilBundleFallsBackToDefault() {
        #expect(FormattingProfiles.resolve(bundleID: nil).name == "Default")
    }
}
```

`FormattingPromptBuilderTests.swift`:
```swift
import Testing
@testable import SadaaCore

@Suite struct FormattingPromptBuilderTests {
    @Test func testIncludesProfileAndSpeakerContext() {
        let prompt = FormattingPromptBuilder.systemPrompt(
            profile: FormattingProfiles.code,
            dictionaryWords: [],
            speakerContext: "The speaker is an AI specialist.")
        #expect(prompt.contains("code editor or terminal"))
        #expect(prompt.contains("The speaker is an AI specialist."))
        #expect(prompt.contains("\"newTerms\""))
    }

    @Test func testIncludesDictionaryWhenPresent() {
        let prompt = FormattingPromptBuilder.systemPrompt(
            profile: FormattingProfiles.default,
            dictionaryWords: ["Karko AI", "Supabase"],
            speakerContext: "ctx")
        #expect(prompt.contains("Enforce these exact spellings"))
        #expect(prompt.contains("Karko AI, Supabase"))
    }

    @Test func testOmitsDictionaryLineWhenEmpty() {
        let prompt = FormattingPromptBuilder.systemPrompt(
            profile: FormattingProfiles.default,
            dictionaryWords: [],
            speakerContext: "ctx")
        #expect(!prompt.contains("Enforce these exact spellings"))
    }
}
```

- [ ] **Step 5: Run tests, expect pass**

Run: `make test`
Expected: green, new tests included.

- [ ] **Step 6: Commit**

```bash
git add Sources/SadaaCore/Formatting Tests/SadaaCoreTests/FormattingProfileTests.swift Tests/SadaaCoreTests/FormattingPromptBuilderTests.swift
git commit -m "feat: add formatting profiles, context types and system-prompt builder"
```

---

### Task B: AzureChatFormatter (SadaaCore, TDD)

**Files:**
- Create: `Sources/SadaaCore/Formatting/AzureChatFormatter.swift`
- Test: `Tests/SadaaCoreTests/AzureChatFormatterTests.swift`

- [ ] **Step 1: Write the formatter**

`AzureChatFormatter.swift`:
```swift
import Foundation

/// Azure OpenAI chat-completions smart formatter. Spec section 3.6.
/// POST {endpoint}/openai/deployments/{deployment}/chat/completions?api-version=...
/// @unchecked Sendable: both stored properties (Config, URLSession) are Sendable, no mutable state.
public final class AzureChatFormatter: @unchecked Sendable {
    public struct Config: Sendable {
        public let endpoint: URL
        public let apiKey: String
        public let deployment: String
        public let apiVersion: String

        public init(endpoint: URL, apiKey: String,
                    deployment: String, apiVersion: String) {
            self.endpoint = endpoint
            self.apiKey = apiKey
            self.deployment = deployment
            self.apiVersion = apiVersion
        }
    }

    private let config: Config
    private let session: URLSession

    public init(config: Config, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public func makeRequest(rawTranscript: String,
                            context: FormattingContext) throws -> URLRequest {
        let profile = FormattingProfiles.resolve(bundleID: context.appBundleID)
        let system = FormattingPromptBuilder.systemPrompt(
            profile: profile,
            dictionaryWords: context.dictionaryWords,
            speakerContext: context.speakerContext)

        var components = URLComponents(
            url: config.endpoint.appendingPathComponent(
                "openai/deployments/\(config.deployment)/chat/completions"),
            resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "api-version",
                                              value: config.apiVersion)]

        let payload: [String: Any] = [
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": rawTranscript],
            ],
            "temperature": 0.2,
            "response_format": ["type": "json_object"],
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(config.apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 15
        return request
    }

    public func format(rawTranscript: String,
                       context: FormattingContext) async throws -> FormattingResult {
        let request = try makeRequest(rawTranscript: rawTranscript, context: context)
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
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ProviderError.http(http.statusCode,
                                     String(decoding: data, as: UTF8.self))
        }
        return try Self.parse(data, fallbackRaw: rawTranscript)
    }

    /// Pulls the assistant message, then decodes its JSON {text, newTerms}.
    /// If the content is not the expected JSON, treats the whole content as the
    /// formatted text with no new terms (never lose the dictation).
    static func parse(_ data: Data, fallbackRaw: String) throws -> FormattingResult {
        struct Completion: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        guard let completion = try? JSONDecoder().decode(Completion.self, from: data),
              let content = completion.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderError.badResponse
        }

        struct Inner: Decodable { let text: String; let newTerms: [String]? }
        if let inner = try? JSONDecoder().decode(Inner.self, from: Data(content.utf8)) {
            let terms = Array((inner.newTerms ?? []).prefix(3))
            let text = inner.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return FormattingResult(text: text.isEmpty ? fallbackRaw : text,
                                    newTerms: terms)
        }
        return FormattingResult(
            text: content.trimmingCharacters(in: .whitespacesAndNewlines),
            newTerms: [])
    }
}
```

- [ ] **Step 2: Write the failing tests**

`AzureChatFormatterTests.swift`:
```swift
import Testing
import Foundation
@testable import SadaaCore

@Suite(.serialized) struct AzureChatFormatterTests {
    private let config = AzureChatFormatter.Config(
        endpoint: URL(string: "https://myres.openai.azure.com")!,
        apiKey: "test-key",
        deployment: "gpt-4o-mini",
        apiVersion: "2024-10-21")

    private func context(bundle: String? = nil,
                         dict: [String] = []) -> FormattingContext {
        FormattingContext(appBundleID: bundle, dictionaryWords: dict,
                          speakerContext: "The speaker is an AI specialist.",
                          language: .auto)
    }

    @Test func testRequestShape() throws {
        let formatter = AzureChatFormatter(config: config)
        let request = try formatter.makeRequest(
            rawTranscript: "hello", context: context(bundle: "com.microsoft.VSCode"))
        #expect(request.url?.absoluteString ==
            "https://myres.openai.azure.com/openai/deployments/gpt-4o-mini/chat/completions?api-version=2024-10-21")
        #expect(request.value(forHTTPHeaderField: "api-key") == "test-key")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let messages = json["messages"] as! [[String: String]]
        #expect(messages.first?["role"] == "system")
        #expect(messages.first?["content"]?.contains("code editor or terminal") == true)
        #expect(messages.last?["content"] == "hello")
    }

    @Test func testParseStructuredJSON() throws {
        let body = #"{"choices":[{"message":{"content":"{\"text\":\"Hello, world.\",\"newTerms\":[\"Karko\"]}"}}]}"#
        let result = try AzureChatFormatter.parse(Data(body.utf8), fallbackRaw: "raw")
        #expect(result.text == "Hello, world.")
        #expect(result.newTerms == ["Karko"])
    }

    @Test func testParsePlainTextContentFallsBack() throws {
        let body = #"{"choices":[{"message":{"content":"Hello, world."}}]}"#
        let result = try AzureChatFormatter.parse(Data(body.utf8), fallbackRaw: "raw")
        #expect(result.text == "Hello, world.")
        #expect(result.newTerms.isEmpty)
    }

    @Test func testParseCapsNewTermsAtThree() throws {
        let body = #"{"choices":[{"message":{"content":"{\"text\":\"x\",\"newTerms\":[\"a\",\"b\",\"c\",\"d\"]}"}}]}"#
        let result = try AzureChatFormatter.parse(Data(body.utf8), fallbackRaw: "raw")
        #expect(result.newTerms == ["a", "b", "c"])
    }

    @Test func testFormatSuccessViaStub() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "api-key") == "test-key")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            let body = #"{"choices":[{"message":{"content":"{\"text\":\"Polished.\",\"newTerms\":[]}"}}]}"#
            return (response, Data(body.utf8))
        }
        let formatter = AzureChatFormatter(config: config,
                                           session: StubURLProtocol.session())
        let result = try await formatter.format(rawTranscript: "polished",
                                                context: context())
        #expect(result.text == "Polished.")
    }

    @Test func testHTTPErrorThrows() async throws {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data("nope".utf8))
        }
        let formatter = AzureChatFormatter(config: config,
                                           session: StubURLProtocol.session())
        do {
            _ = try await formatter.format(rawTranscript: "x", context: context())
            Issue.record("expected ProviderError")
        } catch let ProviderError.http(status, _) {
            #expect(status == 401)
        }
    }
}
```

- [ ] **Step 3: Run, expect pass; commit**

Run: `make test`
```bash
git add Sources/SadaaCore/Formatting/AzureChatFormatter.swift Tests/SadaaCoreTests/AzureChatFormatterTests.swift
git commit -m "feat: add AzureChatFormatter for smart formatting via Azure GPT"
```

---

### Task C: DictionaryStore + base vocabulary (SadaaCore, TDD)

**Files:**
- Create: `Sources/SadaaCore/Dictionary/DictionaryEntry.swift`
- Create: `Sources/SadaaCore/Dictionary/BaseVocabulary.swift`
- Create: `Sources/SadaaCore/Dictionary/DictionaryStore.swift`
- Test: `Tests/SadaaCoreTests/DictionaryStoreTests.swift`

- [ ] **Step 1: Entry + base vocab**

`DictionaryEntry.swift`:
```swift
import Foundation

public struct DictionaryEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var word: String
    public var soundsLike: String?

    public init(id: UUID = UUID(), word: String, soundsLike: String? = nil) {
        self.id = id
        self.word = word
        self.soundsLike = soundsLike
    }
}
```

`BaseVocabulary.swift`:
```swift
import Foundation

/// Shipped, read-only AI/dev terms that bias recognition without polluting the
/// user's personal list. Spec section 4 "Dictionary lifecycle". Deliberately small.
public enum BaseVocabulary {
    public static let terms: [String] = [
        "Claude", "Claude Code", "Codex", "Anthropic", "OpenAI", "Whisper",
        "MCP", "LLM", "RAG", "agent", "token", "repo", "PR", "Supabase",
        "Next.js", "Vercel", "Stripe", "Bedrock", "Tailwind", "TypeScript",
        "Karko AI", "Sadaa", "SwiftUI", "Xcode", "GitHub", "API", "JSON",
        "endpoint", "deployment", "Azure", "prompt", "embeddings", "fine-tune",
        "TypeScript", "webhook", "Postgres", "Redis", "Docker", "Kubernetes",
    ]
}
```

`DictionaryStore.swift`:
```swift
import Foundation

/// Personal dictionary plus formatter-driven suggestions, persisted as JSON.
/// Mirrors DictationHistory's best-effort, corruption-tolerant approach.
/// Used on the main actor; not Sendable.
public final class DictionaryStore {
    private struct Persisted: Codable {
        var entries: [DictionaryEntry]
        var dismissed: [String]
        var pending: [String]
    }

    private let fileURL: URL
    private var entries: [DictionaryEntry]   // newest/most-recent first
    private var dismissed: [String]          // lowercased, never suggested again
    private var pending: [String]            // awaiting accept/dismiss

    public init(fileURL: URL) {
        self.fileURL = fileURL
        guard let data = try? Data(contentsOf: fileURL) else {
            entries = []; dismissed = []; pending = []
            return
        }
        if let decoded = try? JSONDecoder().decode(Persisted.self, from: data) {
            entries = decoded.entries
            dismissed = decoded.dismissed
            pending = decoded.pending
        } else {
            try? FileManager.default.moveItem(
                at: fileURL, to: fileURL.appendingPathExtension("bak"))
            entries = []; dismissed = []; pending = []
        }
    }

    // MARK: - Personal entries

    public func all() -> [DictionaryEntry] { entries }

    public func add(word: String, soundsLike: String? = nil) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entries.removeAll { $0.word.caseInsensitiveCompare(trimmed) == .orderedSame }
        entries.insert(DictionaryEntry(word: trimmed, soundsLike: soundsLike), at: 0)
        save()
    }

    public func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    /// Personal words (most-recent first) then base terms, de-duped
    /// case-insensitively and capped at `budget`. Spec section 4 step 2.
    public func biasList(budget: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for word in entries.map(\.word) + BaseVocabulary.terms {
            let key = word.lowercased()
            if seen.insert(key).inserted { result.append(word) }
            if result.count == budget { break }
        }
        return result
    }

    // MARK: - Suggestions

    public func pendingSuggestions() -> [String] { pending }

    /// Queues formatter-guessed terms that are not already personal, not
    /// dismissed, and not already pending. Keeps at most the 10 newest.
    public func suggest(_ terms: [String]) {
        for term in terms {
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if dismissed.contains(key) { continue }
            if pending.contains(where: { $0.lowercased() == key }) { continue }
            if entries.contains(where: { $0.word.lowercased() == key }) { continue }
            pending.append(trimmed)
        }
        if pending.count > 10 { pending.removeFirst(pending.count - 10) }
        save()
    }

    public func accept(_ term: String) {
        pending.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        add(word: term) // save() called inside add()
    }

    public func dismiss(_ term: String) {
        pending.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        dismissed.append(term.lowercased())
        save()
    }

    private func save() {
        let snapshot = Persisted(entries: entries, dismissed: dismissed, pending: pending)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
```

- [ ] **Step 2: Write the failing tests**

`DictionaryStoreTests.swift`:
```swift
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
```

- [ ] **Step 3: Run, expect pass; commit**

Run: `make test`
```bash
git add Sources/SadaaCore/Dictionary Tests/SadaaCoreTests/DictionaryStoreTests.swift
git commit -m "feat: add DictionaryStore with bias list, suggestions and base vocabulary"
```

---

### Task D: Wire formatter + raw-mode + suggestions into DictationController (SadaaCore, TDD)

**Files:**
- Modify: `Sources/SadaaCore/DictationController.swift`
- Modify: `Tests/SadaaCoreTests/DictationControllerTests.swift`

- [ ] **Step 1: Extend the controller**

Add stored properties and init params (all defaulted so existing call sites compile):
```swift
    private let format: ((String, FormattingContext) async throws -> FormattingResult)?
    private let context: () -> FormattingContext
    private let suggestTerms: ([String]) -> Void
    private let formatterFellBack: () -> Void
    private var pendingRawMode = false
```

Init signature (append after `record:`):
```swift
                record: @escaping (DictationRecord) -> Void = { _ in },
                format: ((String, FormattingContext) async throws -> FormattingResult)? = nil,
                context: @escaping () -> FormattingContext = {
                    FormattingContext(appBundleID: nil, dictionaryWords: [],
                                      speakerContext: "", language: .auto)
                },
                suggestTerms: @escaping ([String]) -> Void = { _ in },
                formatterFellBack: @escaping () -> Void = {}) {
```
Assign them in the body alongside the existing assignments:
```swift
        self.format = format
        self.context = context
        self.suggestTerms = suggestTerms
        self.formatterFellBack = formatterFellBack
```

Change `toggle()` to accept raw mode and capture it on the stop transition:
```swift
    public func toggle(rawMode: Bool = false) {
        switch state {
        case .idle, .error:
            startRecording()
        case .recording:
            pendingRawMode = rawMode
            state = .transcribing
            processingTask = Task { await stopAndProcess() }
        case .transcribing, .delivering:
            break
        }
    }
```

In `stopAndProcess`, replace the block from `try? store.saveTranscript(...)` through `deliver(transcript.text)` with:
```swift
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
            durationSeconds: transcript.durationSeconds))

        state = .delivering
        deliver(finalText)
```

- [ ] **Step 2: Add controller tests**

Append to `DictationControllerTests.swift` (extend `makeController` to take optional hooks, and add tests). Add capture vars to the suite:
```swift
    private var suggested: [String] = []
    private var fellBack = false
```
Reset them in `init()` (`suggested = []; fellBack = false`). Add a second helper:
```swift
    private func makeFormattingController(
        providers: [TranscriptionProvider],
        format: @escaping (String, FormattingContext) async throws -> FormattingResult)
        -> DictationController {
        let controller = DictationController(
            recorder: recorder,
            providers: { providers },
            store: store,
            hint: { TranscriptionHint(languagePin: .auto, dictionaryWords: []) },
            recordingsToKeep: 10,
            deliver: { [weak self] text in self?.delivered.append(text) },
            record: { [weak self] record in self?.records.append(record) },
            format: format,
            context: { FormattingContext(appBundleID: nil, dictionaryWords: [],
                                         speakerContext: "", language: .auto) },
            suggestTerms: { [weak self] terms in self?.suggested.append(contentsOf: terms) },
            formatterFellBack: { [weak self] in self?.fellBack = true })
        controller.onStateChange = { [weak self] state in self?.states.append(state) }
        return controller
    }
```
Tests:
```swift
    @Test func testFormatterAppliedAndTermsSuggested() async throws {
        let provider = FakeProvider(name: "fake",
            result: .success(Transcript(text: "hello world",
                                        detectedLanguage: "english", durationSeconds: 1)))
        let controller = makeFormattingController(providers: [provider]) { raw, _ in
            #expect(raw == "hello world")
            return FormattingResult(text: "Hello, world.", newTerms: ["Karko"])
        }
        controller.toggle()
        await controller.toggleAndWait()
        #expect(delivered == ["Hello, world."])
        #expect(records.first?.text == "Hello, world.")
        #expect(suggested == ["Karko"])
        // raw still in the sidecar
        let sidecar = recorder.startedURL!.deletingPathExtension()
            .appendingPathExtension("txt")
        #expect(try String(contentsOf: sidecar, encoding: .utf8) == "hello world")
    }

    @Test func testRawModeSkipsFormatter() async throws {
        let provider = FakeProvider(name: "fake",
            result: .success(Transcript(text: "hello world",
                                        detectedLanguage: nil, durationSeconds: nil)))
        let controller = makeFormattingController(providers: [provider]) { _, _ in
            Issue.record("formatter must not run in raw mode")
            return FormattingResult(text: "WRONG", newTerms: [])
        }
        controller.toggle()                 // start
        controller.toggle(rawMode: true)    // stop, raw
        await controller.toggleAndWait()
        #expect(delivered == ["hello world"])
    }

    @Test func testFormatterFailureFallsBackToRaw() async throws {
        struct Boom: Error {}
        let provider = FakeProvider(name: "fake",
            result: .success(Transcript(text: "hello world",
                                        detectedLanguage: nil, durationSeconds: nil)))
        let controller = makeFormattingController(providers: [provider]) { _, _ in
            throw Boom()
        }
        controller.toggle()
        await controller.toggleAndWait()
        #expect(delivered == ["hello world"])
        #expect(fellBack)
    }
```
Note: `toggle(rawMode: true)` is called while `.recording`; `toggleAndWait()` then awaits the already-started `processingTask`. Calling `toggle()` inside `toggleAndWait` while `.transcribing` is a no-op, which is correct.

- [ ] **Step 3: Run, expect pass; commit**

Run: `make test`
```bash
git add Sources/SadaaCore/DictationController.swift Tests/SadaaCoreTests/DictationControllerTests.swift
git commit -m "feat: wire smart formatting, raw-mode and term suggestions into DictationController"
```

---

### Task E: AppSettings formatting fields + Settings UI (SadaaApp)

**Files:**
- Modify: `Sources/SadaaCore/Settings/AppSettings.swift`
- Modify: `Sources/SadaaApp/Pages/SettingsPage.swift`

- [ ] **Step 1: AppSettings fields**

Add keys and accessors:
```swift
        static let gptDeployment = "gptDeployment"
        static let formattingEnabled = "formattingEnabled"
        static let speakerContext = "speakerContext"
```
```swift
    public var gptDeployment: String {
        get { defaults.string(forKey: Keys.gptDeployment) ?? "" }
        set { defaults.set(newValue, forKey: Keys.gptDeployment) }
    }

    /// Smart formatting on/off. Spec section 8 default: on.
    public var formattingEnabled: Bool {
        get { defaults.object(forKey: Keys.formattingEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.formattingEnabled) }
    }

    /// Editable speaker-context line fed to the formatter. Spec section 4.
    public var speakerContext: String {
        get {
            defaults.string(forKey: Keys.speakerContext) ??
            "The speaker is an AI specialist and founder; dictations are usually about AI engineering and dev tooling. Resolve ambiguous words toward that domain (\"cloud code\" means \"Claude Code\", \"codecs\" means \"Codex\")."
        }
        set { defaults.set(newValue, forKey: Keys.speakerContext) }
    }
```

- [ ] **Step 2: Settings UI (Formatting section)**

In `SettingsPage`, add `@State` vars near the others:
```swift
    @State private var formattingEnabled = true
    @State private var gptDeployment = ""
    @State private var speakerContext = ""
```
Add a section after the Azure section (inside the `Form`):
```swift
                    Section("Smart formatting") {
                        Toggle("Format dictations with GPT", isOn: $formattingEnabled)
                        TextField("GPT deployment name (e.g. gpt-4o-mini)",
                                  text: $gptDeployment)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Speaker context").font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $speakerContext)
                                .frame(minHeight: 64)
                                .font(.system(size: 12))
                        }
                        Text("Hold Shift when you stop to skip formatting for one dictation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
```
Extend `load()`:
```swift
        formattingEnabled = settings.formattingEnabled
        gptDeployment = settings.gptDeployment
        speakerContext = settings.speakerContext
```
Extend `save()` (before `viewModel.refreshConfig()`):
```swift
        settings.formattingEnabled = formattingEnabled
        settings.gptDeployment = gptDeployment
            .trimmingCharacters(in: .whitespacesAndNewlines)
        settings.speakerContext = speakerContext
```

- [ ] **Step 3: Build, commit**

Run: `swift build && make test`
```bash
git add Sources/SadaaCore/Settings/AppSettings.swift Sources/SadaaApp/Pages/SettingsPage.swift
git commit -m "feat: add formatting settings (toggle, GPT deployment, speaker context)"
```

---

### Task F: Dictionary page + view-model + AppDelegate wiring + deploy (SadaaApp)

**Files:**
- Modify: `Sources/SadaaApp/SadaaViewModel.swift`
- Modify: `Sources/SadaaApp/Pages/DictionaryPage.swift`
- Modify: `Sources/SadaaApp/RootView.swift` (pass view-model to DictionaryPage if needed)
- Modify: `Sources/SadaaApp/AppDelegate.swift`

- [ ] **Step 1: View-model dictionary surface**

In `SadaaViewModel`, add:
```swift
    @Published var dictionaryEntries: [DictionaryEntry] = []
    @Published var dictionarySuggestions: [String] = []

    let dictionary: DictionaryStore
```
Add `dictionary: DictionaryStore` to `init` params, assign it, and call `refreshDictionary()` in init. Methods:
```swift
    func refreshDictionary() {
        dictionaryEntries = dictionary.all()
        dictionarySuggestions = dictionary.pendingSuggestions()
    }

    func addDictionaryWord(_ word: String, soundsLike: String?) {
        dictionary.add(word: word,
                       soundsLike: (soundsLike?.isEmpty == false) ? soundsLike : nil)
        refreshDictionary()
    }

    func removeDictionaryEntry(_ id: UUID) {
        dictionary.remove(id: id)
        refreshDictionary()
    }

    func acceptSuggestion(_ term: String) {
        dictionary.accept(term)
        refreshDictionary()
    }

    func dismissSuggestion(_ term: String) {
        dictionary.dismiss(term)
        refreshDictionary()
    }
```

- [ ] **Step 2: Real Dictionary page**

Replace `DictionaryPage.swift` body with a manager bound to the view-model (add `@ObservedObject var viewModel: SadaaViewModel`, `@State private var newWord = ""`, `@State private var newSoundsLike = ""`). Render: a "Suggestions" section (only when non-empty) with accept/dismiss buttons per term; an "Add word" row (two TextFields + Add button); and a list of entries with a delete button each, all in Karko colors. Keep copy em-dash-free. Wire RootView to pass `viewModel` into `DictionaryPage(viewModel:)`.

- [ ] **Step 3: AppDelegate wiring**

In `setUpController`:
- Build the dictionary store next to history:
```swift
        let dictionary = DictionaryStore(
            fileURL: sadaaDir.appendingPathComponent("dictionary.json"))
        self.dictionary = dictionary
```
  (Add `private var dictionary: DictionaryStore?` as a stored property, and pass `dictionary` into `SadaaViewModel(...)`.)
- Change the `hint` closure to bias from the dictionary:
```swift
            hint: { [settings, dictionary] in
                TranscriptionHint(languagePin: settings.languagePin,
                                  dictionaryWords: dictionary.biasList(budget: 50))
            },
```
- Add formatter build + format/context/suggest/fallback hooks to the `DictationController(...)` init:
```swift
            format: Self.buildFormatter(settings: settings).map { formatter in
                { raw, ctx in try await formatter.format(rawTranscript: raw, context: ctx) }
            },
            context: { [settings, dictionary] in
                FormattingContext(
                    appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                    dictionaryWords: dictionary.biasList(budget: 50),
                    speakerContext: settings.speakerContext,
                    language: settings.languagePin)
            },
            suggestTerms: { [weak self] terms in
                self?.dictionary?.suggest(terms)
                self?.viewModel?.refreshDictionary()
            },
            formatterFellBack: { [weak self] in
                self?.hud.show(.error("Inserted raw text (formatter offline)."))
                self?.hud.hide(after: 4)
            }
```
- Add the builder:
```swift
    private static func buildFormatter(settings: AppSettings) -> AzureChatFormatter? {
        guard settings.formattingEnabled,
              !settings.gptDeployment.isEmpty,
              let endpoint = URL(string: settings.azureEndpoint),
              !settings.azureEndpoint.isEmpty,
              let key = Keychain.get(account: "azure-openai-key")
        else { return nil }
        let config = AzureChatFormatter.Config(
            endpoint: endpoint, apiKey: key,
            deployment: settings.gptDeployment,
            apiVersion: settings.azureAPIVersion)
        return AzureChatFormatter(config: config)
    }
```
- Raw-mode on Shift: change `startHotkeys`'s toggle wiring:
```swift
        hotkeys.onToggle = { [weak self] in
            let raw = NSEvent.modifierFlags.contains(.shift)
            self?.controller?.toggle(rawMode: raw)
        }
```
  (Leave the menu `menuToggle` calling `controller?.toggle()` plain.)

Note: `buildFormatter` is captured once at wiring time. After the user edits formatting settings, the change applies on next app launch. Acceptable for Plan 2 (matches how providers are built); a settings-time rebuild is a later polish.

- [ ] **Step 4: Build, test, deploy, smoke**

Run: `swift build -c release` (zero warnings), `make test` (green), `make bundle && make install`.

Live smoke (report results): dictate a sentence into a code editor and confirm formatted output; dictate into Mail/Notes and confirm fuller punctuation; hold Shift on stop and confirm raw text; add a dictionary word and confirm it is enforced; trigger a suggestion and accept/dismiss it; break the GPT deployment name and confirm raw fallback with the HUD note; confirm transcription still works with formatting off.

- [ ] **Step 5: Commit**

```bash
git add Sources/SadaaApp
git commit -m "feat: wire dictionary biasing, smart formatter and raw-mode into the app"
```

---

## Self-review notes
- Spec coverage: formatter (B), profiles+prompt (A), raw-mode (D/F), dictionary manual+bias (C/F), auto-suggest loop (C/D/F), settings (E), dictionary UI (F). Section 3.6 formatter, section 4 profiles/dictionary, section 8 raw-mode default all mapped.
- All controller hooks are defaulted so the existing 34 tests stay green.
- `DictionaryEntry`, `FormattingContext`, `FormattingResult`, `FormattingProfile`, method names (`biasList`, `suggest`, `accept`, `dismiss`, `format`, `toggle(rawMode:)`) are consistent across tasks.
- Out of scope for Plan 2 (deferred): profile editing UI, snippet expansion in the formatter (Plan 4), cost meter (Plan 3), settings-time formatter rebuild.
