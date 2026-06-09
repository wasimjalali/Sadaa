import Foundation

/// Everything the formatter needs about one dictation besides the raw text.
public struct FormattingContext: Sendable {
    public let appBundleID: String?
    public let dictionaryWords: [String]
    public let speakerContext: String
    public let language: LanguagePin
    public let snippets: [Snippet]

    public init(appBundleID: String?,
                dictionaryWords: [String],
                speakerContext: String,
                language: LanguagePin,
                snippets: [Snippet] = []) {
        self.appBundleID = appBundleID
        self.dictionaryWords = dictionaryWords
        self.speakerContext = speakerContext
        self.language = language
        self.snippets = snippets
    }
}

/// How a dictation's text was produced. Recorded per dictation so History can
/// show whether Prompt Mode actually ran (its absence is the diagnostic).
public enum FormattingMode: String, Codable, Equatable, Sendable {
    case raw        // pure transcription: raw toggle, formatter off, or fallback
    case formatted  // smart formatting cleaned it up
    case prompt     // Prompt Mode rewrote it for a target model
}

/// What the formatter returns: polished text plus up to a few newly guessed terms.
public struct FormattingResult: Equatable, Sendable {
    public let text: String
    public let newTerms: [String]
    /// How this text was produced; the pipeline copies it onto the record.
    public let mode: FormattingMode
    /// Display name of the Prompt Mode target ("Claude"), nil unless mode == .prompt.
    public let promptTarget: String?

    public init(text: String, newTerms: [String],
                mode: FormattingMode = .formatted, promptTarget: String? = nil) {
        self.text = text
        self.newTerms = newTerms
        self.mode = mode
        self.promptTarget = promptTarget
    }
}
