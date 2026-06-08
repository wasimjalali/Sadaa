import Foundation

/// Personal dictionary plus formatter-driven suggestions, persisted as JSON.
/// Mirrors DictationHistory's best-effort, corruption-tolerant approach.
/// Used on the main actor; not Sendable.
public final class DictionaryStore {
    private struct Persisted: Codable {
        var entries: [DictionaryEntry]
        var dismissed: [String]
        var pending: [String]
    }

    private let fileURL: URL
    private var entries: [DictionaryEntry]   // newest/most-recent first
    private var dismissed: [String]          // lowercased, never suggested again
    private var pending: [String]            // awaiting accept/dismiss

    public init(fileURL: URL) {
        self.fileURL = fileURL
        guard let data = try? Data(contentsOf: fileURL) else {
            entries = []; dismissed = []; pending = []
            return
        }
        if let decoded = try? JSONDecoder().decode(Persisted.self, from: data) {
            entries = decoded.entries
            dismissed = decoded.dismissed
            pending = decoded.pending
        } else {
            try? FileManager.default.moveItem(
                at: fileURL, to: fileURL.appendingPathExtension("bak"))
            entries = []; dismissed = []; pending = []
        }
    }

    // MARK: - Personal entries

    public func all() -> [DictionaryEntry] { entries }

    public func add(word: String, soundsLike: String? = nil) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entries.removeAll { $0.word.caseInsensitiveCompare(trimmed) == .orderedSame }
        entries.insert(DictionaryEntry(word: trimmed, soundsLike: soundsLike), at: 0)
        save()
    }

    public func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    /// Personal words (most-recent first) then base terms, de-duped
    /// case-insensitively and capped at `budget`. Spec section 4 step 2.
    public func biasList(budget: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for word in entries.map(\.word) + BaseVocabulary.terms {
            let key = word.lowercased()
            if seen.insert(key).inserted { result.append(word) }
            if result.count == budget { break }
        }
        return result
    }

    // MARK: - Suggestions

    public func pendingSuggestions() -> [String] { pending }

    /// Queues formatter-guessed terms that are not already personal, not
    /// dismissed, and not already pending. Keeps at most the 10 newest.
    public func suggest(_ terms: [String]) {
        for term in terms {
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if dismissed.contains(key) { continue }
            if pending.contains(where: { $0.lowercased() == key }) { continue }
            if entries.contains(where: { $0.word.lowercased() == key }) { continue }
            pending.append(trimmed)
        }
        if pending.count > 10 { pending.removeFirst(pending.count - 10) }
        save()
    }

    public func accept(_ term: String) {
        pending.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        add(word: term) // save() called inside add()
    }

    public func dismiss(_ term: String) {
        pending.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        dismissed.append(term.lowercased())
        save()
    }

    private func save() {
        let snapshot = Persisted(entries: entries, dismissed: dismissed, pending: pending)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
