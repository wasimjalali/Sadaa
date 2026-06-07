import Testing
import Foundation
@testable import SadaaCore

@Suite(.serialized) struct AzureOpenAIProviderTests {
    private let config = AzureOpenAIProvider.Config(
        endpoint: URL(string: "https://myres.openai.azure.com")!,
        apiKey: "test-key",
        deployment: "whisper",
        apiVersion: "2024-10-21"
    )

    private func makeProvider(session: URLSession = .shared) -> AzureOpenAIProvider {
        AzureOpenAIProvider(config: config, session: session)
    }

    @Test func testRequestShape() throws {
        let provider = makeProvider()
        let hint = TranscriptionHint(languagePin: .auto, dictionaryWords: [])
        let request = try provider.makeRequest(audio: Data([0x01]),
                                               filename: "a.wav", hint: hint)

        #expect(
            request.url?.absoluteString ==
            "https://myres.openai.azure.com/openai/deployments/whisper/audio/transcriptions?api-version=2024-10-21"
        )
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "api-key") == "test-key")
        #expect(request.value(forHTTPHeaderField: "Content-Type")!
            .hasPrefix("multipart/form-data; boundary="))

        let body = String(decoding: request.httpBody!, as: UTF8.self)
        #expect(body.contains("name=\"response_format\"\r\n\r\nverbose_json"))
        #expect(body.contains("name=\"temperature\"\r\n\r\n0"))
        #expect(!body.contains("name=\"language\""), "auto pin omits language")
        #expect(!body.contains("name=\"prompt\""), "empty dictionary omits prompt")
    }

    @Test func testRequestWithPinAndDictionary() throws {
        let provider = makeProvider()
        let hint = TranscriptionHint(languagePin: .de,
                                     dictionaryWords: ["Karko", "Supabase"])
        let request = try provider.makeRequest(audio: Data([0x01]),
                                               filename: "a.wav", hint: hint)
        let body = String(decoding: request.httpBody!, as: UTF8.self)
        #expect(body.contains("name=\"language\"\r\n\r\nde"))
        #expect(body.contains("name=\"prompt\"\r\n\r\nKarko, Supabase"))
    }

    @Test func testParseVerboseJSON() throws {
        let json = #"{"text":"Hallo Welt.","language":"german","duration":2.5}"#
        let transcript = try AzureOpenAIProvider.parse(Data(json.utf8))
        #expect(transcript.text == "Hallo Welt.")
        #expect(transcript.detectedLanguage == "german")
        #expect(transcript.durationSeconds == 2.5)
    }

    @Test func testTranscribeSuccessViaStubbedSession() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "api-key") == "test-key")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"text":"hello","language":"english","duration":1.0}"#.utf8))
        }
        let provider = makeProvider(session: StubURLProtocol.session())

        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("stub-\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let transcript = try await provider.transcribe(
            audio: audioURL,
            hint: TranscriptionHint(languagePin: .auto, dictionaryWords: []))
        #expect(transcript.text == "hello")
    }

    @Test func testHTTPErrorThrows() async throws {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"error":{"message":"bad key"}}"#.utf8))
        }
        let provider = makeProvider(session: StubURLProtocol.session())

        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("stub-\(UUID().uuidString).wav")
        try Data([0x00]).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        do {
            _ = try await provider.transcribe(
                audio: audioURL,
                hint: TranscriptionHint(languagePin: .auto, dictionaryWords: []))
            Issue.record("expected ProviderError")
        } catch let ProviderError.http(status, _) {
            #expect(status == 401)
        }
    }
}

/// URLProtocol stub so provider tests never touch the network.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else { return }
        do {
            // Body arrives as a stream when set via httpBody on URLSession upload.
            var request = self.request
            if request.httpBody == nil, let stream = request.httpBodyStream {
                stream.open()
                var data = Data()
                let bufferSize = 4096
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate() }
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: bufferSize)
                    if read <= 0 { break }
                    data.append(buffer, count: read)
                }
                stream.close()
                request.httpBody = data
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response,
                                cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
