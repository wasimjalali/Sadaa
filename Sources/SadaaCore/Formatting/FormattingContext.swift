import Foundation

/// Everything the formatter needs about one dictation besides the raw text.
public struct FormattingContext: Sendable {
    public let appBundleID: String?
    public let dictionaryWords: [String]
    public let speakerContext: String
    public let language: LanguagePin

    public init(appBundleID: String?,
                dictionaryWords: [String],
                speakerContext: String,
                language: LanguagePin) {
        self.appBundleID = appBundleID
        self.dictionaryWords = dictionaryWords
        self.speakerContext = speakerContext
        self.language = language
    }
}

/// What the formatter returns: polished text plus up to a few newly guessed terms.
public struct FormattingResult: Equatable, Sendable {
    public let text: String
    public let newTerms: [String]

    public init(text: String, newTerms: [String]) {
        self.text = text
        self.newTerms = newTerms
    }
}
