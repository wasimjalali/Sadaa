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
    /// How the text was produced (raw or formatted). Optional so pre-mode
    /// history.json still decodes.
    public let mode: FormattingMode?

    public init(id: UUID = UUID(), text: String, createdAt: Date,
                language: String?, provider: String, durationSeconds: Double?,
                estimatedCost: Double? = nil, mode: FormattingMode? = nil) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.language = language
        self.provider = provider
        self.durationSeconds = durationSeconds
        self.estimatedCost = estimatedCost
        self.mode = mode
    }

    public func withEstimatedCost(_ cost: Double?) -> DictationRecord {
        DictationRecord(id: id, text: text, createdAt: createdAt, language: language,
                        provider: provider, durationSeconds: durationSeconds,
                        estimatedCost: cost, mode: mode)
    }
}
