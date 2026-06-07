import Testing
import Foundation
@testable import SadaaCore

@Suite struct MultipartBodyTests {
    @Test func testEncodesFieldsAndFile() {
        var body = MultipartBody(boundary: "BOUNDARY")
        body.addField(name: "temperature", value: "0")
        body.addFile(name: "file", filename: "audio.wav",
                     contentType: "audio/wav", data: Data([0x01, 0x02]))
        let encoded = String(decoding: body.encoded(), as: UTF8.self)

        #expect(body.contentType == "multipart/form-data; boundary=BOUNDARY")
        #expect(encoded.contains("--BOUNDARY\r\n"))
        #expect(encoded.contains(
            "Content-Disposition: form-data; name=\"temperature\"\r\n\r\n0\r\n"))
        #expect(encoded.contains(
            "Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n"))
        #expect(encoded.contains("Content-Type: audio/wav\r\n"))
        #expect(encoded.hasSuffix("--BOUNDARY--\r\n"))
    }

    @Test func testNonASCIIFieldValue() {
        var body = MultipartBody(boundary: "B")
        body.addField(name: "prompt", value: "Ü, straße")
        let data = body.encoded()
        #expect(String(decoding: data, as: UTF8.self).contains("Ü, straße"))
        let needle = Data("Ü, straße".utf8)
        #expect(data.range(of: needle) != nil)
    }
}
