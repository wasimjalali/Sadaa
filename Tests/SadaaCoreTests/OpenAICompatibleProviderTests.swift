import Testing
import Foundation
@testable import SadaaCore

@Suite(.serialized) struct OpenAICompatibleProviderTests {
    private func provider(
        baseURL: String = "https://speech.example.com",
        apiKey: String = "test-token",
        model: String = "whisper-large-v3",
        session: URLSession = .shared
    ) -> OpenAICompatibleProvider {
        OpenAICompatibleProvider(
            config: .init(
                baseURL: URL(string: baseURL)!,
                apiKey: apiKey,
                model: model
            ),
            session: session
        )
    }

    @Test func testRequestShapeUsesStandardAudioTranscriptionsEndpoint() throws {
        let request = try provider().makeRequest(
            audio: Data([0x01]),
            filename: "sample.wav",
            hint: TranscriptionHint(
                languagePin: .de,
                dictionaryWords: ["Sadaa", "Claude Code"]
            )
        )

        #expect(request.url?.absoluteString == "https://speech.example.com/v1/audio/transcriptions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true)

        let body = String(decoding: request.httpBody!, as: UTF8.self)
        #expect(body.contains("name=\"model\"\r\n\r\nwhisper-large-v3"))
        #expect(body.contains("name=\"response_format\"\r\n\r\njson"))
        #expect(body.contains("name=\"language\"\r\n\r\nde"))
        #expect(body.contains("name=\"prompt\"\r\n\r\nSadaa, Claude Code"))
        #expect(body.contains("name=\"file\"; filename=\"sample.wav\""))
    }

    @Test func testRequestAllowsLocalEndpointWithoutApiKey() throws {
        let request = try provider(
            baseURL: "http://127.0.0.1:8080/v1/",
            apiKey: ""
        ).makeRequest(
            audio: Data([0x01]),
            filename: "sample.wav",
            hint: TranscriptionHint(languagePin: .auto, dictionaryWords: [])
        )

        #expect(request.url?.absoluteString == "http://127.0.0.1:8080/v1/audio/transcriptions")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        let body = String(decoding: request.httpBody!, as: UTF8.self)
        #expect(!body.contains("name=\"language\""))
        #expect(!body.contains("name=\"prompt\""))
    }

    @Test func testRequestRejectsBearerTokenOverRemoteHTTP() {
        #expect(throws: ProviderError.self) {
            try provider(
                baseURL: "http://speech.example.com",
                apiKey: "test-token"
            ).makeRequest(
                audio: Data([0x01]),
                filename: "sample.wav",
                hint: TranscriptionHint(languagePin: .auto, dictionaryWords: [])
            )
        }
    }

    @Test func testTranscribeParsesOpenAICompatibleJSON() async throws {
        CompatibleStubURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"text":"  hello from Sadaa  ","language":"en","duration":1.25}"#.utf8))
        }
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("compatible-\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let transcript = try await provider(session: CompatibleStubURLProtocol.session()).transcribe(
            audio: audioURL,
            hint: TranscriptionHint(languagePin: .auto, dictionaryWords: [])
        )

        #expect(transcript.text == "hello from Sadaa")
        #expect(transcript.detectedLanguage == "en")
        #expect(transcript.durationSeconds == 1.25)
    }
}

private final class CompatibleStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CompatibleStubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else { return }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
