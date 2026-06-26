import Foundation

public enum MemoryBiasBuilder {
    public static func biasList(terms: [MemoryTerm],
                                baseVocabulary: [String],
                                budget: Int,
                                language: MemoryLanguage = .auto) -> [String] {
        guard budget > 0 else { return [] }

        let sortedTerms = terms
            .filter { term in
                term.language == .auto || language == .auto || term.language == language
            }
            .sorted { lhs, rhs in
                let leftRank = priorityRank(lhs.priority)
                let rightRank = priorityRank(rhs.priority)
                if leftRank != rightRank { return leftRank < rightRank }
                if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
                return lhs.updatedAt > rhs.updatedAt
            }

        var seen = Set<String>()
        var result: [String] = []

        func append(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, result.count < budget else { return }
            let key = TermMatcher.canonical(trimmed)
            guard !key.isEmpty, seen.insert(key).inserted else { return }
            result.append(trimmed)
        }

        for term in sortedTerms {
            append(term.phrase)
            for alias in term.aliases { append(alias) }
            for pronunciation in term.pronunciations { append(pronunciation) }
            if result.count == budget { return result }
        }

        for word in baseVocabulary {
            append(word)
            if result.count == budget { return result }
        }

        return result
    }

    private static func priorityRank(_ priority: MemoryPriority) -> Int {
        switch priority {
        case .always: return 0
        case .high: return 1
        case .normal: return 2
        }
    }
}
