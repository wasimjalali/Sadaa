import Testing
import Foundation
@testable import SadaaCore

private struct HealthFakeProvider: TranscriptionProvider {
    let name: String
    let result: Result<Transcript, Error>

    func transcribe(audio: URL, hint: TranscriptionHint) async throws -> Transcript {
        #expect(FileManager.default.fileExists(atPath: audio.path))
        return try result.get()
    }
}

@Suite(.serialized) struct ProviderHealthCheckTests {
    @Test func testRedactionRemovesPathAndQuery() {
        let redacted = ProviderHealthCheck.redactedEndpoint(
            "https://example.openai.azure.com/openai/deployments/x?api-key=secret"
        )
        #expect(redacted == "https://example.openai.azure.com")
    }

    @Test func testSanitizeRemovesKeysAndBearerTokens() {
        let message = #"api-key: abc123 Bearer token.secret Ocp-Apim-Subscription-Key="speech""#
        let sanitized = ProviderHealthCheck.sanitize(message)
        #expect(!sanitized.contains("abc123"))
        #expect(!sanitized.contains("token.secret"))
        #expect(!sanitized.contains("speech"))
    }

    @Test func testHealthCheckSuccessReportsLatencyAndRedactedEndpoint() async {
        let provider = HealthFakeProvider(
            name: "Fake",
            result: .success(Transcript(text: "", detectedLanguage: nil, durationSeconds: nil))
        )
        var dates = [
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 10.25),
        ]
        let result = await ProviderHealthCheck.check(
            provider: provider,
            endpoint: "https://example.openai.azure.com/private?api-key=secret",
            hint: TranscriptionHint(languagePin: .auto, dictionaryWords: []),
            now: { dates.isEmpty ? Date(timeIntervalSince1970: 10.25) : dates.removeFirst() }
        )

        #expect(result.ok)
        #expect(result.latencyMilliseconds == 250)
        #expect(result.redactedEndpoint == "https://example.openai.azure.com")
        #expect(!result.message.contains("secret"))
    }

    @Test func testHealthCheckFailureSanitizesProviderBody() async {
        let provider = HealthFakeProvider(
            name: "Fake",
            result: .failure(ProviderError.http(401, #"api-key: secret"#))
        )
        let result = await ProviderHealthCheck.check(
            provider: provider,
            endpoint: "https://example.openai.azure.com",
            hint: TranscriptionHint(languagePin: .auto, dictionaryWords: [])
        )

        #expect(!result.ok)
        #expect(result.message.contains("HTTP 401"))
        #expect(!result.message.contains("secret"))
    }

    @Test func testFormatterHealthCheckSuccessReportsFormattedProbe() async throws {
        FormatterHealthStubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            let body = #"{"choices":[{"message":{"content":"{\"text\":\"Hello, world.\",\"newTerms\":[]}"}}]}"#
            return (response, Data(body.utf8))
        }
        let formatter = AzureChatFormatter(
            config: .init(
                endpoint: URL(string: "https://example.openai.azure.com")!,
                apiKey: "test-key",
                deployment: "gpt-5.5-nano",
                apiVersion: "2025-03-01-preview"
            ),
            session: FormatterHealthStubURLProtocol.session()
        )
        var dates = [
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 10.25),
        ]

        let result = await FormatterHealthCheck.check(
            formatter: formatter,
            endpoint: "https://example.openai.azure.com/private?api-key=secret",
            now: { dates.isEmpty ? Date(timeIntervalSince1970: 10.25) : dates.removeFirst() }
        )

        #expect(result.providerName == "Azure GPT")
        #expect(result.ok)
        #expect(result.latencyMilliseconds == 250)
        #expect(result.message == "connected; \"Hello, world.\"")
        #expect(result.redactedEndpoint == "https://example.openai.azure.com")
    }

    @Test func testFormatterHealthCheckFailureShowsDeploymentErrorWithoutSecrets() async throws {
        FormatterHealthStubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404,
                                           httpVersion: nil, headerFields: nil)!
            let body = #"{"error":{"code":"DeploymentNotFound","message":"api-key: secret deployment missing"}}"#
            return (response, Data(body.utf8))
        }
        let formatter = AzureChatFormatter(
            config: .init(
                endpoint: URL(string: "https://example.openai.azure.com")!,
                apiKey: "test-key",
                deployment: "missing",
                apiVersion: "2025-03-01-preview"
            ),
            session: FormatterHealthStubURLProtocol.session()
        )

        let result = await FormatterHealthCheck.check(
            formatter: formatter,
            endpoint: "https://example.openai.azure.com"
        )

        #expect(!result.ok)
        #expect(result.message.contains("HTTP 404"))
        #expect(result.message.contains("DeploymentNotFound"))
        #expect(!result.message.contains("secret"))
    }
}

final class FormatterHealthStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FormatterHealthStubURLProtocol.self]
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
