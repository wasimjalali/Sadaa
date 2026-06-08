import Testing
import Foundation
@testable import SadaaCore

@Suite(.serialized) struct OpenAIProviderTests {
    private let config = OpenAIProvider.Config(apiKey: "test-key", model: "whisper-1")

    private func makeProvider(session: URLSession = .shared) -> OpenAIProvider {
        OpenAIProvider(config: config, session: session)
    }

    @Test func testRequestShape() throws {
        let provider = makeProvider()
        let request = try provider.makeRequest(
            audio: Data([0x01]), filename: "a.wav",
            hint: TranscriptionHint(languagePin: .auto, dictionaryWords: []))
        #expect(request.url?.absoluteString == "https://api.openai.com/v1/audio/transcriptions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        let body = String(decoding: request.httpBody!, as: UTF8.self)
        #expect(body.contains("name=\"model\"\r\n\r\nwhisper-1"))
        #expect(body.contains("name=\"response_format\"\r\n\r\nverbose_json"))
        #expect(!body.contains("name=\"language\""))
    }

    @Test func testGPT4oTranscribeModelUsesPlainJSON() throws {
        // The gpt-4o-transcribe family rejects verbose_json. whisper-1 keeps it
        // (and its accurate duration); the gpt-4o models must get plain json.
        let provider = OpenAIProvider(
            config: .init(apiKey: "test-key", model: "gpt-4o-transcribe"))
        let request = try provider.makeRequest(
            audio: Data([0x01]), filename: "a.wav",
            hint: TranscriptionHint(languagePin: .auto, dictionaryWords: []))
        let body = String(decoding: request.httpBody!, as: UTF8.self)
        #expect(body.contains("name=\"response_format\"\r\n\r\njson\r\n"))
        #expect(!body.contains("verbose_json"))
    }

    @Test func testRequestWithPinAndDictionary() throws {
        let provider = makeProvider()
        let request = try provider.makeRequest(
            audio: Data([0x01]), filename: "a.wav",
            hint: TranscriptionHint(languagePin: .en, dictionaryWords: ["Karko"]))
        let body = String(decoding: request.httpBody!, as: UTF8.self)
        #expect(body.contains("name=\"language\"\r\n\r\nen"))
        #expect(body.contains("name=\"prompt\"\r\n\r\nKarko"))
    }

    @Test func testTranscribeSuccessViaStub() async throws {
        OpenAIStubURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"text":"hi","language":"english","duration":1.0}"#.utf8))
        }
        let provider = makeProvider(session: OpenAIStubURLProtocol.session())
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("stub-\(UUID().uuidString).wav")
        try Data([0x52]).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let transcript = try await provider.transcribe(
            audio: audioURL, hint: TranscriptionHint(languagePin: .auto, dictionaryWords: []))
        #expect(transcript.text == "hi")
    }

    @Test func testHTTPErrorThrows() async throws {
        OpenAIStubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data("bad key".utf8))
        }
        let provider = makeProvider(session: OpenAIStubURLProtocol.session())
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("stub-\(UUID().uuidString).wav")
        try Data([0x00]).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        do {
            _ = try await provider.transcribe(
                audio: audioURL, hint: TranscriptionHint(languagePin: .auto, dictionaryWords: []))
            Issue.record("expected ProviderError")
        } catch let ProviderError.http(status, _) {
            #expect(status == 401)
        }
    }
}

/// URLProtocol stub isolated to the OpenAI tests so its handler never races the
/// other network suites' globals under parallel execution.
final class OpenAIStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OpenAIStubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else { return }
        do {
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
