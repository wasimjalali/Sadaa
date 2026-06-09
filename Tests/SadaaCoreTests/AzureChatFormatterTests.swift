import Testing
import Foundation
@testable import SadaaCore

@Suite(.serialized) struct AzureChatFormatterTests {
    private let config = AzureChatFormatter.Config(
        endpoint: URL(string: "https://myres.openai.azure.com")!,
        apiKey: "test-key",
        deployment: "gpt-4o-mini",
        apiVersion: "2024-10-21")

    private func context(bundle: String? = nil,
                         dict: [String] = []) -> FormattingContext {
        FormattingContext(appBundleID: bundle, dictionaryWords: dict,
                          speakerContext: "The speaker is an AI specialist.",
                          language: .auto)
    }

    @Test func testRequestShape() throws {
        let formatter = AzureChatFormatter(config: config)
        let request = try formatter.makeRequest(
            rawTranscript: "hello", context: context(bundle: "com.microsoft.VSCode"))
        #expect(request.url?.absoluteString ==
            "https://myres.openai.azure.com/openai/deployments/gpt-4o-mini/chat/completions?api-version=2024-10-21")
        #expect(request.value(forHTTPHeaderField: "api-key") == "test-key")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let messages = json["messages"] as! [[String: String]]
        #expect(messages.first?["role"] == "system")
        #expect(messages.first?["content"]?.contains("code editor or terminal") == true)
        #expect(messages.last?["content"] == "<transcript>\nhello\n</transcript>")
    }

    @Test func testParseStructuredJSON() throws {
        let body = #"{"choices":[{"message":{"content":"{\"text\":\"Hello, world.\",\"newTerms\":[\"Karko\"]}"}}]}"#
        let result = try AzureChatFormatter.parse(Data(body.utf8), fallbackRaw: "raw")
        #expect(result.text == "Hello, world.")
        #expect(result.newTerms == ["Karko"])
    }

    @Test func testParsePlainTextContentFallsBack() throws {
        let body = #"{"choices":[{"message":{"content":"Hello, world."}}]}"#
        let result = try AzureChatFormatter.parse(Data(body.utf8), fallbackRaw: "raw")
        #expect(result.text == "Hello, world.")
        #expect(result.newTerms.isEmpty)
    }

    @Test func testParseCapsNewTermsAtThree() throws {
        let body = #"{"choices":[{"message":{"content":"{\"text\":\"x\",\"newTerms\":[\"a\",\"b\",\"c\",\"d\"]}"}}]}"#
        let result = try AzureChatFormatter.parse(Data(body.utf8), fallbackRaw: "raw")
        #expect(result.newTerms == ["a", "b", "c"])
    }

    @Test func testFormatSuccessViaStub() async throws {
        ChatStubURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "api-key") == "test-key")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            let body = #"{"choices":[{"message":{"content":"{\"text\":\"Polished.\",\"newTerms\":[]}"}}]}"#
            return (response, Data(body.utf8))
        }
        let formatter = AzureChatFormatter(config: config,
                                           session: ChatStubURLProtocol.session())
        let result = try await formatter.format(rawTranscript: "polished",
                                                context: context())
        #expect(result.text == "Polished.")
    }

    @Test func testOptimizeStampsPromptModeAndTarget() async throws {
        ChatStubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            let body = #"{"choices":[{"message":{"content":"{\"text\":\"Optimized.\",\"newTerms\":[]}"}}]}"#
            return (response, Data(body.utf8))
        }
        let formatter = AzureChatFormatter(config: config,
                                           session: ChatStubURLProtocol.session())
        let result = try await formatter.optimize(
            rawTranscript: "raw", context: context(),
            pack: ModelPackLibrary.pack(for: .claude))
        #expect(result.text == "Optimized.")
        #expect(result.mode == .prompt)
        #expect(result.promptTarget == "Claude")
    }

    @Test func testOptimizeMalformedContentThrowsInsteadOfDeliveringVerbatim() async throws {
        // The optimizer promises {text, newTerms} JSON. When the model answers
        // with anything else, delivering it verbatim pastes garbage into the
        // user's editor; the pipeline must fall back to the raw transcript.
        ChatStubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            let body = #"{"choices":[{"message":{"content":"Sure! Here is your optimized prompt."}}]}"#
            return (response, Data(body.utf8))
        }
        let formatter = AzureChatFormatter(config: config,
                                           session: ChatStubURLProtocol.session())
        do {
            _ = try await formatter.optimize(
                rawTranscript: "raw", context: context(),
                pack: ModelPackLibrary.pack(for: .gpt))
            Issue.record("expected ProviderError.badResponse")
        } catch {
            guard case ProviderError.badResponse = error else {
                Issue.record("expected badResponse, got \(error)")
                return
            }
        }
    }

    @Test func testOptimizeEmptyInnerTextThrows() async throws {
        ChatStubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            let body = #"{"choices":[{"message":{"content":"{\"text\":\"  \",\"newTerms\":[]}"}}]}"#
            return (response, Data(body.utf8))
        }
        let formatter = AzureChatFormatter(config: config,
                                           session: ChatStubURLProtocol.session())
        do {
            _ = try await formatter.optimize(
                rawTranscript: "raw", context: context(),
                pack: ModelPackLibrary.pack(for: .claude))
            Issue.record("expected ProviderError.badResponse")
        } catch {
            guard case ProviderError.badResponse = error else {
                Issue.record("expected badResponse, got \(error)")
                return
            }
        }
    }

    @Test func testHTTPErrorThrows() async throws {
        ChatStubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data("nope".utf8))
        }
        let formatter = AzureChatFormatter(config: config,
                                           session: ChatStubURLProtocol.session())
        do {
            _ = try await formatter.format(rawTranscript: "x", context: context())
            Issue.record("expected ProviderError")
        } catch let ProviderError.http(status, _) {
            #expect(status == 401)
        }
    }
}

/// URLProtocol stub isolated to the formatter tests so its handler never races
/// the provider suite's global `StubURLProtocol.handler` under parallel suites.
final class ChatStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ChatStubURLProtocol.self]
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
