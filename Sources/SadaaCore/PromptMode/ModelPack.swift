import Foundation

/// The model families Prompt Mode can optimize a dictated prompt for.
public enum ModelPackID: String, CaseIterable, Sendable {
    case claude, gpt, gemini, generic

    public var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .gpt: return "GPT"
        case .gemini: return "Gemini"
        case .generic: return "Generic"
        }
    }
}

/// A model family plus the prompting guidance the optimizer should follow for
/// it. The guidance is markdown embedded as a Swift string, optionally replaced
/// by a user-edited file on disk.
public struct ModelPack: Equatable, Sendable {
    public let id: ModelPackID
    public let guidance: String

    public init(id: ModelPackID, guidance: String) {
        self.id = id
        self.guidance = guidance
    }
}
