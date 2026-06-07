import Foundation

/// Minimal multipart/form-data encoder for transcription uploads.
public struct MultipartBody {
    public let boundary: String
    private var data = Data()

    public init(boundary: String = "sadaa-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    public var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    /// NOTE: callers are responsible for keeping CRLF sequences out of values.
    public mutating func addField(name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    public mutating func addFile(name: String, filename: String,
                                 contentType: String, data fileData: Data) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(contentType)\r\n\r\n")
        data.append(fileData)
        append("\r\n")
    }

    public func encoded() -> Data {
        var out = data
        out.append(Data("--\(boundary)--\r\n".utf8))
        return out
    }

    private mutating func append(_ string: String) {
        data.append(Data(string.utf8))
    }
}
