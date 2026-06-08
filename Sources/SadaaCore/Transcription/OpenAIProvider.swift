import Foundation

/// OpenAI batch transcription fallback. Spec section 3.4.
/// POST https://api.openai.com/v1/audio/transcriptions (Bearer auth, explicit model).
/// @unchecked Sendable: no mutable state; stored properties are Sendable.
public final class OpenAIProvider: TranscriptionProvider, @unchecked Sendable {
    public struct Config: Sendable {
        public let apiKey: String
        public let model: String   // e.g. "whisper-1" or "gpt-4o-transcribe"

        public init(apiKey: String, model: String) {
            self.apiKey = apiKey
            self.model = model
        }
    }

    public let name = "OpenAI"
    private let config: Config
    private let session: URLSession
    private let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    public init(config: Config, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public func makeRequest(audio: Data, filename: String,
                            hint: TranscriptionHint) throws -> URLRequest {
        var body = MultipartBody()
        body.addField(name: "model", value: config.model)
        // whisper-1 supports verbose_json (and returns duration); the
        // gpt-4o-transcribe family rejects it and needs plain json.
        let responseFormat = config.model.lowercased().contains("transcribe")
            ? "json" : "verbose_json"
        body.addField(name: "response_format", value: responseFormat)
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

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body.encoded()
        request.timeoutInterval = 15
        return request
    }

    public func transcribe(audio: URL,
                           hint: TranscriptionHint) async throws -> Transcript {
        let audioData = try Data(contentsOf: audio)
        let request = try makeRequest(audio: audioData,
                                      filename: audio.lastPathComponent, hint: hint)
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
        return try AzureOpenAIProvider.parse(data)
    }
}
