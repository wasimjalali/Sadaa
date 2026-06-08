import Testing
import Foundation
@testable import SadaaCore

@Suite struct AzureSpeechProviderTests {
    private let config = AzureSpeechProvider.Config(
        endpoint: URL(string: "https://myres.cognitiveservices.azure.com")!,
        apiKey: "speech-key")

    private func makeProvider() -> AzureSpeechProvider {
        AzureSpeechProvider(config: config)
    }

    /// Pulls the JSON value of a named multipart field out of the encoded body.
    private func definitionJSON(from request: URLRequest) throws -> [String: Any] {
        let body = String(decoding: request.httpBody!, as: UTF8.self)
        // The definition field value sits between its header and the next CRLF.
        guard let range = body.range(of: "name=\"definition\"\r\n\r\n") else {
            Issue.record("definition field missing"); return [:]
        }
        let after = body[range.upperBound...]
        guard let end = after.range(of: "\r\n--") else {
            Issue.record("definition terminator missing"); return [:]
        }
        let json = String(after[..<end.lowerBound])
        return try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
    }

    @Test func testRequestShape() throws {
        let request = try makeProvider().makeRequest(
            audio: Data([0x01]), filename: "a.wav",
            hint: TranscriptionHint(languagePin: .auto, dictionaryWords: ["Karko", "Sadaa"]))
        #expect(request.url?.absoluteString ==
            "https://myres.cognitiveservices.azure.com/speechtotext/transcriptions:transcribe?api-version=2025-10-15")
        #expect(request.value(forHTTPHeaderField: "Ocp-Apim-Subscription-Key") == "speech-key")

        let definition = try definitionJSON(from: request)
        #expect(definition["locales"] as? [String] == ["en-US", "de-DE"])
        let phraseList = definition["phraseList"] as? [String: Any]
        #expect(phraseList?["phrases"] as? [String] == ["Karko", "Sadaa"])
        let enhanced = definition["enhancedMode"] as? [String: Any]
        #expect(enhanced?["enabled"] as? Bool == true)
        #expect(enhanced?["model"] as? String == "mai-transcribe-1.5")
    }

    @Test func testPinnedLocale() throws {
        let request = try makeProvider().makeRequest(
            audio: Data([0x01]), filename: "a.wav",
            hint: TranscriptionHint(languagePin: .de, dictionaryWords: []))
        let definition = try definitionJSON(from: request)
        #expect(definition["locales"] as? [String] == ["de-DE"])
    }

    @Test func testParseCombinedPhrases() throws {
        let json = #"{"combinedPhrases":[{"text":"Hallo Welt.","locale":"de-DE"}],"durationMilliseconds":2500}"#
        let transcript = try AzureSpeechProvider.parse(Data(json.utf8))
        #expect(transcript.text == "Hallo Welt.")
        #expect(transcript.detectedLanguage == "de-DE")
        #expect(transcript.durationSeconds == 2.5)
    }

    @Test func testParseMissingPhrasesThrows() {
        let json = #"{"durationMilliseconds":1000}"#
        #expect(throws: ProviderError.self) {
            _ = try AzureSpeechProvider.parse(Data(json.utf8))
        }
    }
}
