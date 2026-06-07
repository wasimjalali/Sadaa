import Foundation

/// Azure OpenAI batch transcription. Spec section 3.2.
/// POST {endpoint}/openai/deployments/{deployment}/audio/transcriptions?api-version=...
public final class AzureOpenAIProvider: TranscriptionProvider, @unchecked Sendable {
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

    public let name = "Azure OpenAI"
    private let config: Config
    private let session: URLSession

    public init(config: Config, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public func makeRequest(audio: Data, filename: String,
                            hint: TranscriptionHint) throws -> URLRequest {
        var components = URLComponents(
            url: config.endpoint
                .appendingPathComponent("openai/deployments/\(config.deployment)/audio/transcriptions"),
            resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "api-version",
                                              value: config.apiVersion)]

        var body = MultipartBody()
        body.addField(name: "response_format", value: "verbose_json")
        body.addField(name: "temperature", value: "0")
        if hint.languagePin != .auto {
            body.addField(name: "language", value: hint.languagePin.rawValue)
        }
        if !hint.dictionaryWords.isEmpty {
            body.addField(name: "prompt",
                          value: hint.dictionaryWords.joined(separator: ", "))
        }
        body.addFile(name: "file", filename: filename,
                     contentType: "audio/wav", data: audio)

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(config.apiKey, forHTTPHeaderField: "api-key")
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body.encoded()
        request.timeoutInterval = 15 // spec 3.5: fallback timeout
        return request
    }

    public func transcribe(audio: URL,
                           hint: TranscriptionHint) async throws -> Transcript {
        let audioData = try Data(contentsOf: audio)
        let request = try makeRequest(audio: audioData,
                                      filename: audio.lastPathComponent, hint: hint)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ProviderError.http(http.statusCode,
                                     String(decoding: data, as: UTF8.self))
        }
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> Transcript {
        struct VerboseJSON: Decodable {
            let text: String
            let language: String?
            let duration: Double?
        }
        guard let decoded = try? JSONDecoder().decode(VerboseJSON.self, from: data) else {
            throw ProviderError.badResponse
        }
        return Transcript(text: decoded.text.trimmingCharacters(in: .whitespacesAndNewlines),
                          detectedLanguage: decoded.language,
                          durationSeconds: decoded.duration)
    }
}
