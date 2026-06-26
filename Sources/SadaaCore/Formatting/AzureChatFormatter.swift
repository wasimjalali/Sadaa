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
            speakerContext: context.speakerContext,
            snippets: context.snippets,
            language: context.language,
            replacementRules: context.replacementRules)

        var components = URLComponents(
            url: AzureOpenAIProvider.baseURL(from: config.endpoint).appendingPathComponent(
                "openai/deployments/\(config.deployment)/chat/completions"),
            resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "api-version",
                                              value: config.apiVersion)]

        let payload: [String: Any] = [
            "messages": [
                ["role": "system", "content": system],
                // Delimit the dictation so the model treats it as data to
                // transcribe, not instructions to follow.
                ["role": "user", "content": "<transcript>\n\(rawTranscript)\n</transcript>"],
            ],
            // Low but not zero: enough for natural punctuation and list
            // formatting. The guardrail prompt, not the temperature, is what
            // keeps it from acting on the content.
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

    // MARK: - Voice edit (rewrite a selection per a spoken instruction)

    public func makeRewriteRequest(selection: String,
                                   instruction: String,
                                   context: FormattingContext) throws -> URLRequest {
        var components = URLComponents(
            url: AzureOpenAIProvider.baseURL(from: config.endpoint).appendingPathComponent(
                "openai/deployments/\(config.deployment)/chat/completions"),
            resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "api-version",
                                              value: config.apiVersion)]

        // Threads the same context the dictation path uses (app tone profile,
        // who the speaker is, the language pin and dictionary) so a voice edit
        // carries the right voice, and decides compose-a-reply vs edit-in-place
        // from the instruction. The selection and instruction are delimited so
        // a command hidden in the selected text can't hijack the edit.
        let profile = FormattingProfiles.resolve(bundleID: context.appBundleID)
        let system = VoiceEditPromptBuilder.systemPrompt(
            profile: profile,
            dictionaryWords: context.dictionaryWords,
            speakerContext: context.speakerContext,
            language: context.language)
        let user = "<instruction>\n\(instruction)\n</instruction>\n\n<selection>\n\(selection)\n</selection>"
        let payload: [String: Any] = [
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            // A touch warmer than the formatting path (0.2): composing a natural
            // reply needs a little more room than cleaning up a transcript.
            "temperature": 0.4,
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(config.apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 15
        return request
    }

    /// Returns the edited selection. The assistant content is the rewrite itself.
    public func rewrite(selection: String, instruction: String,
                        context: FormattingContext) async throws -> String {
        let request = try makeRewriteRequest(selection: selection,
                                             instruction: instruction, context: context)
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
        return try Self.parseContent(data)
    }

    /// Plain assistant content (used by rewrite, which returns text not JSON).
    static func parseContent(_ data: Data) throws -> String {
        struct Completion: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        guard let completion = try? JSONDecoder().decode(Completion.self, from: data),
              let content = completion.choices.first?.message.content?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw ProviderError.badResponse
        }
        return content
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
        if let inner = try? JSONDecoder().decode(
            Inner.self, from: Data(Self.stripCodeFence(content).utf8)) {
            let terms = Array((inner.newTerms ?? []).prefix(3))
            let text = inner.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return FormattingResult(text: text.isEmpty ? fallbackRaw : text,
                                    newTerms: terms)
        }
        return FormattingResult(
            text: content.trimmingCharacters(in: .whitespacesAndNewlines),
            newTerms: [])
    }

    /// Strips a wrapping markdown code fence (```json … ``` or ``` … ```) when
    /// the model adds one despite being told not to, so strict JSON decoding
    /// still succeeds. Returns the content unchanged when there is no fence.
    static func stripCodeFence(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```"), trimmed.hasSuffix("```"),
              let firstNewline = trimmed.firstIndex(of: "\n") else { return content }
        let afterOpening = trimmed[trimmed.index(after: firstNewline)...]
        guard let closingFence = afterOpening.range(of: "```", options: .backwards) else {
            return content
        }
        return afterOpening[..<closingFence.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
