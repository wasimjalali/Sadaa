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

    public func makeResponsesRequest(rawTranscript: String,
                                     context: FormattingContext) throws -> URLRequest {
        let profile = FormattingProfiles.resolve(bundleID: context.appBundleID)
        let system = FormattingPromptBuilder.systemPrompt(
            profile: profile,
            dictionaryWords: context.dictionaryWords,
            speakerContext: context.speakerContext,
            snippets: context.snippets,
            language: context.language,
            replacementRules: context.replacementRules)

        var request = URLRequest(url: responsesEndpointURL())
        request.httpMethod = "POST"
        request.setValue(config.apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": config.deployment,
            "instructions": system,
            "input": "<transcript>\n\(rawTranscript)\n</transcript>",
            "text": [
                "format": Self.formattingResponseSchema,
            ],
        ])
        request.timeoutInterval = 15
        return request
    }

    public func format(rawTranscript: String,
                       context: FormattingContext) async throws -> FormattingResult {
        let request = try makeRequest(rawTranscript: rawTranscript, context: context)
        do {
            return try Self.parse(try await send(request), fallbackRaw: rawTranscript)
        } catch {
            let primaryError = error
            guard shouldTryResponsesFallback(after: primaryError) else { throw primaryError }
            do {
                let fallback = try makeResponsesRequest(rawTranscript: rawTranscript, context: context)
                return try Self.parse(try await send(fallback), fallbackRaw: rawTranscript)
            } catch {
                throw Self.combinedError(primary: primaryError, fallback: error)
            }
        }
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

    public func makeResponsesRewriteRequest(selection: String,
                                            instruction: String,
                                            context: FormattingContext) throws -> URLRequest {
        let profile = FormattingProfiles.resolve(bundleID: context.appBundleID)
        let system = VoiceEditPromptBuilder.systemPrompt(
            profile: profile,
            dictionaryWords: context.dictionaryWords,
            speakerContext: context.speakerContext,
            language: context.language)
        let user = "<instruction>\n\(instruction)\n</instruction>\n\n<selection>\n\(selection)\n</selection>"

        var request = URLRequest(url: responsesEndpointURL())
        request.httpMethod = "POST"
        request.setValue(config.apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": config.deployment,
            "instructions": system,
            "input": user,
        ])
        request.timeoutInterval = 15
        return request
    }

    /// Returns the edited selection. The assistant content is the rewrite itself.
    public func rewrite(selection: String, instruction: String,
                        context: FormattingContext) async throws -> String {
        let request = try makeRewriteRequest(selection: selection,
                                             instruction: instruction, context: context)
        do {
            return try Self.parseContent(try await send(request))
        } catch {
            let primaryError = error
            guard shouldTryResponsesFallback(after: primaryError) else { throw primaryError }
            do {
                let fallback = try makeResponsesRewriteRequest(
                    selection: selection,
                    instruction: instruction,
                    context: context)
                return try Self.parseContent(try await send(fallback))
            } catch {
                throw Self.combinedError(primary: primaryError, fallback: error)
            }
        }
    }

    /// Plain assistant content (used by rewrite, which returns text not JSON).
    static func parseContent(_ data: Data) throws -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let content = Self.assistantContent(from: object)?
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
        let content = try Self.parseContent(data)

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

    private static let formattingResponseSchema: [String: Any] = [
        "type": "json_schema",
        "name": "sadaa_formatting_result",
        "strict": true,
        "schema": [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "text": [
                    "type": "string",
                    "description": "The cleaned dictation text. Must not be empty.",
                ],
                "newTerms": [
                    "type": "array",
                    "items": ["type": "string"],
                    "maxItems": 3,
                ],
            ],
            "required": ["text", "newTerms"],
        ],
    ]

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
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
        return data
    }

    private func shouldTryResponsesFallback(after error: Error) -> Bool {
        guard case ProviderError.http(let status, let body) = error,
              status == 400 || status == 404 else { return false }
        let lowered = body.lowercased()
        return status == 404
            || lowered.contains("api version")
            || lowered.contains("deploymentnotfound")
            || lowered.contains("unsupported")
            || lowered.contains("not supported")
            || lowered.contains("response_format")
    }

    private func responsesEndpointURL() -> URL {
        let path = config.endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let base = path.isEmpty ? AzureOpenAIProvider.baseURL(from: config.endpoint) : config.endpoint
        return base.appendingPathComponent("openai/v1/responses")
    }

    private static func combinedError(primary: Error, fallback: Error) -> Error {
        let status: Int
        if case ProviderError.http(let fallbackStatus, _) = fallback {
            status = fallbackStatus
        } else if case ProviderError.http(let primaryStatus, _) = primary {
            status = primaryStatus
        } else {
            return fallback
        }
        let message = "Chat Completions failed: \(compactError(primary)); Responses API failed: \(compactError(fallback))"
        return ProviderError.http(status, message)
    }

    private static func compactError(_ error: Error) -> String {
        if let provider = error as? ProviderError {
            switch provider {
            case .http(let status, let body):
                let detail = summarizeProviderBody(body)
                return detail.isEmpty ? "HTTP \(status)" : "HTTP \(status): \(detail)"
            case .badResponse:
                return "unreadable response"
            case .notConfigured(let what):
                return what
            case .timedOut:
                return "timed out"
            case .transport(let urlError):
                return urlError.localizedDescription
            }
        }
        return ProviderHealthCheck.sanitize(error.localizedDescription)
    }

    private static func summarizeProviderBody(_ body: String) -> String {
        guard let data = body.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = root["error"] as? [String: Any] else {
            return ProviderHealthCheck.sanitize(body.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let code = (error["code"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = (error["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return ProviderHealthCheck.sanitize([code, message]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: ": "))
    }

    private static func assistantContent(from object: Any) -> String? {
        guard let root = object as? [String: Any] else { return nil }
        if let outputText = root["output_text"] as? String {
            return outputText
        }
        if let choices = root["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = contentText(from: message["content"]) {
            return content
        }
        if let output = root["output"] as? [[String: Any]] {
            for item in output {
                if let content = contentText(from: item["content"]) {
                    return content
                }
            }
        }
        return nil
    }

    private static func contentText(from value: Any?) -> String? {
        if let string = value as? String {
            return string
        }
        if let parts = value as? [[String: Any]] {
            let text = parts.compactMap { part -> String? in
                if let text = part["text"] as? String { return text }
                if let text = part["content"] as? String { return text }
                return nil
            }.joined()
            return text.isEmpty ? nil : text
        }
        return nil
    }
}
