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

    @Test func testResponsesRequestUsesProjectEndpointAndSchema() throws {
        let projectConfig = AzureChatFormatter.Config(
            endpoint: URL(string: "https://myres.services.ai.azure.com/api/projects/sadaa")!,
            apiKey: "test-key",
            deployment: "gpt-5.5-nano",
            apiVersion: "2025-03-01-preview")
        let formatter = AzureChatFormatter(config: projectConfig)
        let request = try formatter.makeResponsesRequest(
            rawTranscript: "hello",
            context: context(bundle: "com.microsoft.VSCode"))

        #expect(request.url?.absoluteString ==
            "https://myres.services.ai.azure.com/api/projects/sadaa/openai/v1/responses")
        #expect(request.value(forHTTPHeaderField: "api-key") == "test-key")

        let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(json["model"] as? String == "gpt-5.5-nano")
        #expect((json["instructions"] as? String)?.contains("transcription cleaner") == true)
        #expect(json["input"] as? String == "<transcript>\nhello\n</transcript>")
        let text = json["text"] as! [String: Any]
        let format = text["format"] as! [String: Any]
        #expect(format["type"] as? String == "json_schema")
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

    @Test func testParseResponsesOutputText() throws {
        let body = #"{"output_text":"{\"text\":\"Hello from responses.\",\"newTerms\":[]}"}"#
        let result = try AzureChatFormatter.parse(Data(body.utf8), fallbackRaw: "raw")
        #expect(result.text == "Hello from responses.")
    }

    @Test func testParseResponsesMessageContent() throws {
        let body = #"{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"text\":\"Nested response.\",\"newTerms\":[\"Codex\"]}"}]}]}"#
        let result = try AzureChatFormatter.parse(Data(body.utf8), fallbackRaw: "raw")
        #expect(result.text == "Nested response.")
        #expect(result.newTerms == ["Codex"])
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

    @Test func testFormatFallsBackToResponsesForProjectEndpoint() async throws {
        let projectConfig = AzureChatFormatter.Config(
            endpoint: URL(string: "https://myres.services.ai.azure.com/api/projects/sadaa")!,
            apiKey: "test-key",
            deployment: "gpt-5.5-nano",
            apiVersion: "2025-03-01-preview")
        var urls: [String] = []
        ChatStubURLProtocol.handler = { request in
            urls.append(request.url!.absoluteString)
            if urls.count == 1 {
                let response = HTTPURLResponse(url: request.url!, statusCode: 404,
                                               httpVersion: nil, headerFields: nil)!
                let body = #"{"error":{"code":"DeploymentNotFound","message":"missing legacy route"}}"#
                return (response, Data(body.utf8))
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            let body = #"{"output_text":"{\"text\":\"Responses route worked.\",\"newTerms\":[]}"}"#
            return (response, Data(body.utf8))
        }

        let formatter = AzureChatFormatter(config: projectConfig,
                                           session: ChatStubURLProtocol.session())
        let result = try await formatter.format(rawTranscript: "responses route worked",
                                                context: context())

        #expect(result.text == "Responses route worked.")
        #expect(urls == [
            "https://myres.services.ai.azure.com/openai/deployments/gpt-5.5-nano/chat/completions?api-version=2025-03-01-preview",
            "https://myres.services.ai.azure.com/api/projects/sadaa/openai/v1/responses",
        ])
    }

    @Test func testFormatterErrorCombinesLegacyAndResponsesFailures() async throws {
        let projectConfig = AzureChatFormatter.Config(
            endpoint: URL(string: "https://myres.services.ai.azure.com/api/projects/sadaa")!,
            apiKey: "test-key",
            deployment: "missing",
            apiVersion: "2025-03-01-preview")
        ChatStubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404,
                                           httpVersion: nil, headerFields: nil)!
            let body: String
            if request.url!.absoluteString.contains("/responses") {
                body = #"{"error":{"code":"DeploymentNotFound","message":"responses missing"}}"#
            } else {
                body = #"{"error":{"code":"DeploymentNotFound","message":"legacy missing"}}"#
            }
            return (response, Data(body.utf8))
        }

        let formatter = AzureChatFormatter(config: projectConfig,
                                           session: ChatStubURLProtocol.session())
        do {
            _ = try await formatter.format(rawTranscript: "x", context: context())
            Issue.record("expected ProviderError")
        } catch let ProviderError.http(status, body) {
            #expect(status == 404)
            #expect(body.contains("Chat Completions failed"))
            #expect(body.contains("Responses API failed"))
            #expect(body.contains("DeploymentNotFound"))
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
