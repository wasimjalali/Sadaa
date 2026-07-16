import Foundation

/// Standard OpenAI-compatible batch transcription.
/// POST {baseURL}/v1/audio/transcriptions
public final class OpenAICompatibleProvider: TranscriptionProvider, @unchecked Sendable {
    public struct Config: Sendable {
        public let baseURL: URL
        public let apiKey: String
        public let model: String

        public init(baseURL: URL, apiKey: String, model: String) {
            self.baseURL = baseURL
            self.apiKey = apiKey
            self.model = model
        }
    }

    public let name = "OpenAI-compatible"
    private let config: Config
    private let session: URLSession

    public init(config: Config, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    static func transcriptionURL(from baseURL: URL) -> URL {
        var normalized = baseURL
        while normalized.path.hasSuffix("/") && normalized.path != "/" {
            normalized.deleteLastPathComponent()
        }
        if normalized.path.hasSuffix("/v1") {
            return normalized.appendingPathComponent("audio/transcriptions")
        }
        return normalized.appendingPathComponent("v1/audio/transcriptions")
    }

    public func makeRequest(
        audio: Data,
        filename: String,
        hint: TranscriptionHint
    ) throws -> URLRequest {
        let endpoint = Self.transcriptionURL(from: config.baseURL)
        let apiKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty,
           endpoint.scheme?.lowercased() != "https",
           !Self.isLocalHost(endpoint.host) {
            throw ProviderError.notConfigured("Use HTTPS when a bearer token is configured.")
        }

        var body = MultipartBody()
        body.addField(name: "model", value: config.model)
        body.addField(name: "response_format", value: "json")
        body.addField(name: "temperature", value: "0")
        if hint.languagePin != .auto {
            body.addField(name: "language", value: hint.languagePin.rawValue)
        }
        if !hint.dictionaryWords.isEmpty {
            body.addField(name: "prompt", value: hint.dictionaryWords.joined(separator: ", "))
        }
        body.addFile(
            name: "file",
            filename: filename,
            contentType: "audio/wav",
            data: audio
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body.encoded()
        request.timeoutInterval = AzureOpenAIProvider.totalDeadline
        return request
    }

    private static func isLocalHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "localhost" || host.hasSuffix(".localhost") || host == "127.0.0.1" || host == "::1"
    }

    public func transcribe(audio: URL, hint: TranscriptionHint) async throws -> Transcript {
        let request = try makeRequest(
            audio: Data(contentsOf: audio),
            filename: audio.lastPathComponent,
            hint: hint
        )
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await AzureOpenAIProvider.withDeadline(
                seconds: AzureOpenAIProvider.totalDeadline
            ) { [session] in
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
            throw ProviderError.http(http.statusCode, String(decoding: data, as: UTF8.self))
        }
        return try AzureOpenAIProvider.parse(data)
    }
}
