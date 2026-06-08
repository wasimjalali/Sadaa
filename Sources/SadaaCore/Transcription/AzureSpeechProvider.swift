import Foundation

/// Azure Speech fast transcription (MAI-Transcribe). Spec section 3.3.
/// POST {endpoint}/speechtotext/transcriptions:transcribe?api-version=...
/// Ships behind a settings toggle; not in the default chain until enabled.
/// @unchecked Sendable: no mutable state; stored properties are Sendable.
public final class AzureSpeechProvider: TranscriptionProvider, @unchecked Sendable {
    public struct Config: Sendable {
        public let endpoint: URL       // https://{res}.cognitiveservices.azure.com
        public let apiKey: String
        public let apiVersion: String  // default "2025-10-15"
        public let model: String       // "mai-transcribe-1.5"

        public init(endpoint: URL, apiKey: String,
                    apiVersion: String = "2025-10-15",
                    model: String = "mai-transcribe-1.5") {
            self.endpoint = endpoint
            self.apiKey = apiKey
            self.apiVersion = apiVersion
            self.model = model
        }
    }

    public let name = "MAI"
    private let config: Config
    private let session: URLSession

    public init(config: Config, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public func makeRequest(audio: Data, filename: String,
                            hint: TranscriptionHint) throws -> URLRequest {
        var components = URLComponents(
            url: config.endpoint.appendingPathComponent(
                "speechtotext/transcriptions:transcribe"),
            resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "api-version",
                                              value: config.apiVersion)]

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
        body.addField(name: "definition",
                      value: String(decoding: definitionData, as: UTF8.self))
        body.addFile(name: "audio", filename: filename,
                     contentType: "audio/wav", data: audio)

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(config.apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
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
