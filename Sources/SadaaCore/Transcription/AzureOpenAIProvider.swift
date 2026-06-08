import Foundation

/// Azure OpenAI batch transcription. Spec section 3.2.
/// POST {endpoint}/openai/deployments/{deployment}/audio/transcriptions?api-version=...
/// @unchecked Sendable: no mutable state; both stored properties (Config, URLSession) are Sendable.
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

    /// Reduces a pasted endpoint to scheme://host so the OpenAI REST path can be
    /// appended cleanly. This lets users paste either the classic Azure OpenAI
    /// endpoint (https://res.openai.azure.com) or an Azure AI Foundry project
    /// URL (https://res.services.ai.azure.com/api/projects/name) and have both
    /// resolve to the right base.
    static func baseURL(from endpoint: URL) -> URL {
        var components = URLComponents()
        components.scheme = endpoint.scheme ?? "https"
        components.host = endpoint.host
        components.port = endpoint.port
        return components.url ?? endpoint
    }

    public func makeRequest(audio: Data, filename: String,
                            hint: TranscriptionHint) throws -> URLRequest {
        var components = URLComponents(
            url: Self.baseURL(from: config.endpoint)
                .appendingPathComponent("openai/deployments/\(config.deployment)/audio/transcriptions"),
            resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "api-version",
                                              value: config.apiVersion)]

        var body = MultipartBody()
        // "json" works for whisper-1 AND the gpt-4o-transcribe family. The newer
        // models reject "verbose_json", so we never ask for it (we lose the
        // detected language and duration fields, both optional downstream).
        body.addField(name: "response_format", value: "json")
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
        request.timeoutInterval = 15 // idle timeout; total deadline enforced in transcribe()
        return request
    }

    /// Wall-clock deadline for one provider attempt. Spec 3.5: the fallback
    /// chain moves on after 15 seconds.
    static let totalDeadline: TimeInterval = 15

    /// Races work against a wall-clock deadline. URLRequest.timeoutInterval is
    /// an IDLE timeout (resets on every byte), so a slow trickling upload can
    /// exceed it indefinitely; this enforces a true total cap.
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

    public func transcribe(audio: URL,
                           hint: TranscriptionHint) async throws -> Transcript {
        let audioData = try Data(contentsOf: audio)
        let request = try makeRequest(audio: audioData,
                                      filename: audio.lastPathComponent, hint: hint)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await Self.withDeadline(seconds: Self.totalDeadline) { [session] in
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
