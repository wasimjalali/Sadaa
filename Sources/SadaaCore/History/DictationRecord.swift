import Foundation

public struct DictationRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let createdAt: Date
    public let language: String?
    public let provider: String
    public let durationSeconds: Double?
    /// Credit-awareness estimate. Optional so pre-cost history.json still decodes.
    public let estimatedCost: Double?

    public init(id: UUID = UUID(), text: String, createdAt: Date,
                language: String?, provider: String, durationSeconds: Double?,
                estimatedCost: Double? = nil) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.language = language
        self.provider = provider
        self.durationSeconds = durationSeconds
        self.estimatedCost = estimatedCost
    }

    public func withEstimatedCost(_ cost: Double?) -> DictationRecord {
        DictationRecord(id: id, text: text, createdAt: createdAt, language: language,
                        provider: provider, durationSeconds: durationSeconds,
                        estimatedCost: cost)
    }
}
