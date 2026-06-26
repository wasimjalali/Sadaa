import Foundation

public enum LanguageMemoryLearningEntry: Equatable, Sendable {
    case term(MemoryTerm)
    case replacement(ReplacementRule)
}

public enum LanguageMemoryLearningPolicy {
    public static func makeEntry(observed: String,
                                 corrected: String,
                                 language: MemoryLanguage = .auto,
                                 now: Date = Date()) -> LanguageMemoryLearningEntry {
        let observedTrimmed = observed.trimmingCharacters(in: .whitespacesAndNewlines)
        let correctedTrimmed = corrected.trimmingCharacters(in: .whitespacesAndNewlines)

        if observedTrimmed.caseInsensitiveCompare(correctedTrimmed) == .orderedSame {
            return .term(MemoryTerm(
                phrase: correctedTrimmed,
                language: language,
                priority: .high,
                createdAt: now,
                updatedAt: now
            ))
        }

        return .replacement(ReplacementRule(
            match: observedTrimmed,
            replacement: correctedTrimmed,
            matchMode: .wordBoundaryPhrase,
            language: language,
            createdAt: now,
            updatedAt: now
        ))
    }
}
