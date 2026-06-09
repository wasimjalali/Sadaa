import Testing
import Foundation
@testable import SadaaCore

@Suite(.serialized) struct PromptOptimizeRequestTests {
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

    @Test func testOptimizeRequestShape() throws {
        let formatter = AzureChatFormatter(config: config)
        let pack = ModelPackLibrary.pack(for: .claude)
        let request = try formatter.makeOptimizeRequest(
            rawTranscript: "fix the bug", context: context(), pack: pack)

        #expect(request.url?.absoluteString ==
            "https://myres.openai.azure.com/openai/deployments/gpt-4o-mini/chat/completions?api-version=2024-10-21")
        #expect(request.value(forHTTPHeaderField: "api-key") == "test-key")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let messages = json["messages"] as! [[String: String]]
        #expect(messages.first?["role"] == "system")
        // The system prompt is the optimizer prompt, not the formatter prompt.
        #expect(messages.first?["content"]?.contains("dictation-to-prompt optimizer") == true)
        #expect(messages.first?["content"]?.contains("Lead with context, then the instruction.") == true)
        #expect(messages.last?["content"] == "<transcript>\nfix the bug\n</transcript>")

        let format = json["response_format"] as! [String: String]
        #expect(format["type"] == "json_object")
    }

    @Test func testOptimizeSuccessViaStub() async throws {
        defer { OptimizeStubURLProtocol.handler = nil }
        OptimizeStubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            let body = #"{"choices":[{"message":{"content":"{\"text\":\"Fix the logout bug.\",\"newTerms\":[]}"}}]}"#
            return (response, Data(body.utf8))
        }
        let formatter = AzureChatFormatter(config: config,
                                           session: OptimizeStubURLProtocol.session())
        let result = try await formatter.optimize(
            rawTranscript: "fix the logout thing",
            context: context(),
            pack: ModelPackLibrary.pack(for: .claude))
        #expect(result.text == "Fix the logout bug.")
    }
}

/// Isolated URLProtocol stub for PromptOptimizeRequestTests. Uses a separate
/// class (not ChatStubURLProtocol) so its static handler cannot race with
/// AzureChatFormatterTests, which runs in a concurrent suite.
final class OptimizeStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OptimizeStubURLProtocol.self]
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
