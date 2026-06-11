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
            language: context.language)

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

    // MARK: - Prompt Mode (rewrite a dictation into an optimized prompt)

    /// Builds the chat request for Prompt Mode. Same endpoint, headers,
    /// temperature, JSON response_format and <transcript> delimiting as
    /// makeRequest; the only difference is the optimizer system prompt.
    public func makeOptimizeRequest(rawTranscript: String,
                                    context: FormattingContext,
                                    pack: ModelPack) throws -> URLRequest {
        let system = PromptOptimizerPromptBuilder.systemPrompt(
            pack: pack,
            dictionaryWords: context.dictionaryWords,
            speakerContext: context.speakerContext,
            language: context.language)

        var components = URLComponents(
            url: AzureOpenAIProvider.baseURL(from: config.endpoint).appendingPathComponent(
                "openai/deployments/\(config.deployment)/chat/completions"),
            resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "api-version",
                                              value: config.apiVersion)]

        let payload: [String: Any] = [
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": "<transcript>\n\(rawTranscript)\n</transcript>"],
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

    /// Rewrites a dictation into an optimized prompt for the pack's model
    /// family. Same network handling as format(), but parsing is strict: the
    /// optimizer promised {text, newTerms} JSON, and anything else is a failure
    /// (thrown), so the pipeline falls back to the raw transcript instead of
    /// pasting a malformed response verbatim.
    public func optimize(rawTranscript: String,
                         context: FormattingContext,
                         pack: ModelPack) async throws -> FormattingResult {
        let request = try makeOptimizeRequest(rawTranscript: rawTranscript,
                                              context: context, pack: pack)
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
        let parsed = try Self.parseOptimized(data)
        return FormattingResult(text: parsed.text, newTerms: parsed.newTerms,
                                mode: .prompt,
                                promptTarget: pack.id.displayName)
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

        let system = "You edit the user's selected text according to their spoken instruction. Return ONLY the edited text, with no commentary, no quotes and no markdown. Reply in the same language as the selection."
        let user = "Instruction: \(instruction)\n\nSelected text:\n\(selection)"
        let payload: [String: Any] = [
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "temperature": 0.2,
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

    /// Strict variant for Prompt Mode: the assistant content MUST decode as
    /// {text, newTerms} with non-empty text. Unlike `parse`, a malformed
    /// response throws instead of being delivered verbatim, because pasting a
    /// broken optimizer reply into the user's editor is worse than pasting
    /// the raw dictation.
    static func parseOptimized(_ data: Data) throws -> FormattingResult {
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
        guard let inner = try? JSONDecoder().decode(
            Inner.self, from: Data(stripCodeFence(content).utf8)) else {
            throw ProviderError.badResponse
        }
        let text = inner.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ProviderError.badResponse }
        return FormattingResult(text: text,
                                newTerms: Array((inner.newTerms ?? []).prefix(3)))
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
