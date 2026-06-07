import Foundation

public struct DictationRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let createdAt: Date
    public let language: String?
    public let provider: String
    public let durationSeconds: Double?

    public init(id: UUID = UUID(), text: String, createdAt: Date,
                language: String?, provider: String, durationSeconds: Double?) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.language = language
        self.provider = provider
        self.durationSeconds = durationSeconds
    }
}
