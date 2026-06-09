import SwiftUI
import SadaaCore

/// Personal dictionary manager: pending formatter suggestions to accept or
/// dismiss, an add-word row, and the current entries with delete. Karko styled.
struct DictionaryPage: View {
    @ObservedObject var viewModel: SadaaViewModel

    @State private var newWord = ""
    @State private var newSoundsLike = ""
    @State private var newTrigger = ""
    @State private var newExpansion = ""

    /// Drives the saved-words filter field.
    @State private var search = ""
    @FocusState private var searchFocused: Bool
    /// Brief inline feedback under the add field.
    @State private var showDuplicateNote = false
    @State private var showSavedCheck = false

    private let spring = Animation.spring(response: 0.3, dampingFraction: 0.8)

    /// Saved entries filtered by the current search query (case-insensitive).
    private var filteredEntries: [DictionaryEntry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.dictionaryEntries }
        return viewModel.dictionaryEntries.filter {
            $0.word.localizedCaseInsensitiveContains(query)
                || ($0.soundsLike?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Dictionary")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.charcoal)

                if !viewModel.dictionarySuggestions.isEmpty {
                    suggestionsSection
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                savedSection
                snippetsSection
            }
            .padding(32)
            .frame(maxWidth: 620, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .animation(spring, value: viewModel.dictionarySuggestions)
            .animation(spring, value: viewModel.dictionaryEntries)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.gold)
                    .symbolEffect(.bounce, value: viewModel.dictionarySuggestions.count)
                Text("Suggestions")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.charcoal)
                Text("\(viewModel.dictionarySuggestions.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                    .contentTransition(.numericText())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Theme.gold.opacity(0.12), in: Capsule())
            }
            Text("Sadaa suggests new terms it heard. Accept to teach it the spelling.")
                .font(.caption)
                .foregroundStyle(Theme.charcoal.opacity(0.6))

            FlowLayout(spacing: 8) {
                ForEach(viewModel.dictionarySuggestions, id: \.self) { term in
                    SuggestionChip(
                        term: term,
                        onAccept: {
                            withAnimation(spring) { viewModel.acceptSuggestion(term) }
                        },
                        onDismiss: {
                            withAnimation(spring) { viewModel.dismissSuggestion(term) }
                        })
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Saved words

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Your words")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.charcoal)
                Spacer()
                Text("\(viewModel.dictionaryEntries.count) \(viewModel.dictionaryEntries.count == 1 ? "word" : "words")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.charcoal.opacity(0.55))
                    .contentTransition(.numericText())
            }

            addField

            if viewModel.dictionaryEntries.count > 15 {
                searchField
            }

            entriesList
        }
    }

    private var addField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Add a word (e.g. Karko AI)", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { add() }
                TextField("Sounds like (optional)", text: $newSoundsLike)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { add() }
                Button {
                    add()
                } label: {
                    if showSavedCheck {
                        Image(systemName: "checkmark")
                            .symbolEffect(.bounce, value: showSavedCheck)
                    } else {
                        Text("Add")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(showSavedCheck ? Theme.sage : Theme.navy)
                .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if showDuplicateNote {
                Text("Already saved.")
                    .font(.caption)
                    .foregroundStyle(Theme.charcoal.opacity(0.6))
                    .transition(.opacity)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.charcoal.opacity(0.45))
            TextField("Filter words", text: $search)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !search.isEmpty {
                Button {
                    withAnimation(spring) { search = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.charcoal.opacity(0.35))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.creamSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(searchFocused ? Theme.gold : Theme.charcoal.opacity(0.1),
                        lineWidth: searchFocused ? 1.5 : 1)
        )
        .animation(spring, value: searchFocused)
    }

    @ViewBuilder
    private var entriesList: some View {
        if viewModel.dictionaryEntries.isEmpty {
            emptyState
        } else if filteredEntries.isEmpty {
            noMatchesState
        } else if viewModel.dictionaryEntries.count > 15 {
            // Alphabetically grouped with small gold letter headers.
            let groups = groupedEntries(filteredEntries)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(groups, id: \.key) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.key)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.gold300)
                            .padding(.leading, 2)
                        VStack(spacing: 6) {
                            ForEach(group.entries) { entry in
                                EntryRow(entry: entry) {
                                    withAnimation(spring) {
                                        viewModel.removeDictionaryEntry(entry.id)
                                    }
                                }
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            }
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 6) {
                ForEach(filteredEntries) { entry in
                    EntryRow(entry: entry) {
                        withAnimation(spring) {
                            viewModel.removeDictionaryEntry(entry.id)
                        }
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.gold300)
            Text("No words yet. Add the names and jargon Sadaa keeps getting wrong, or accept a suggestion above.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.charcoal.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var noMatchesState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.gold300)
            Text("No words match that filter.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.charcoal.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Grouping

    private struct EntryGroup {
        let key: String
        let entries: [DictionaryEntry]
    }

    /// Sorts entries alphabetically and groups them by their leading letter.
    /// Non-letter leading characters fall under "#".
    private func groupedEntries(_ entries: [DictionaryEntry]) -> [EntryGroup] {
        let sorted = entries.sorted {
            $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
        }
        var order: [String] = []
        var buckets: [String: [DictionaryEntry]] = [:]
        for entry in sorted {
            let first = entry.word.trimmingCharacters(in: .whitespaces).first
            let key: String
            if let first, first.isLetter {
                key = String(first).uppercased()
            } else {
                key = "#"
            }
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(entry)
        }
        return order.map { EntryGroup(key: $0, entries: buckets[$0] ?? []) }
    }

    // MARK: - Add logic

    private func add() {
        let word = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }

        // UI-level duplicate guard: case-insensitive against displayed words.
        let isDuplicate = viewModel.dictionaryEntries.contains {
            $0.word.compare(word, options: .caseInsensitive) == .orderedSame
        }
        if isDuplicate {
            withAnimation(spring) { showDuplicateNote = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(spring) { showDuplicateNote = false }
            }
            return
        }

        withAnimation(spring) {
            viewModel.addDictionaryWord(
                word,
                soundsLike: newSoundsLike.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        newWord = ""
        newSoundsLike = ""
        showDuplicateNote = false

        withAnimation(spring) { showSavedCheck = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(spring) { showSavedCheck = false }
        }
    }

    // MARK: - Snippets

    private var snippetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Snippets")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.charcoal)
            Text("Say the trigger phrase and Sadaa expands it for you.")
                .font(.caption)
                .foregroundStyle(Theme.charcoal.opacity(0.6))

            HStack(spacing: 8) {
                TextField("Trigger (e.g. my sig)", text: $newTrigger)
                    .textFieldStyle(.roundedBorder)
                TextField("Expands to", text: $newExpansion)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { addSnippet() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.navy)
                    .disabled(newTrigger.trimmingCharacters(in: .whitespaces).isEmpty
                              || newExpansion.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            ForEach(viewModel.snippets) { snippet in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snippet.trigger)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.charcoal)
                        Text(snippet.expansion)
                            .font(.caption)
                            .foregroundStyle(Theme.charcoal.opacity(0.6))
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        withAnimation(spring) { viewModel.removeSnippet(snippet.id) }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Theme.charcoal.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Theme.creamSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(spring, value: viewModel.snippets)
    }

    private func addSnippet() {
        viewModel.addSnippet(
            trigger: newTrigger.trimmingCharacters(in: .whitespacesAndNewlines),
            expansion: newExpansion.trimmingCharacters(in: .whitespacesAndNewlines))
        newTrigger = ""
        newExpansion = ""
    }
}

// MARK: - Suggestion chip

/// A pending suggestion rendered as a creamSurface capsule with sage accept
/// and charcoal dismiss icon buttons.
private struct SuggestionChip: View {
    let term: String
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Text(term)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.navy)
                .lineLimit(1)

            Button(action: onAccept) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.sage)
            }
            .buttonStyle(ChipIconButtonStyle())
            .help("Accept and teach Sadaa this spelling")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.charcoal.opacity(0.55))
            }
            .buttonStyle(ChipIconButtonStyle())
            .help("Dismiss this suggestion")
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .background(Theme.creamSurface, in: Capsule())
        .overlay(
            Capsule().stroke(Theme.gold.opacity(hovering ? 0.35 : 0.12), lineWidth: 1)
        )
        .scaleEffect(hovering ? 1.02 : 1)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hovering)
    }
}

/// Small pressable icon button with a hover background, for the chip controls.
private struct ChipIconButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 22, height: 22)
            .background(
                Circle().fill(Theme.charcoal.opacity(hovering ? 0.06 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .onHover { hovering = $0 }
            .animation(.spring(response: 0.3, dampingFraction: 0.8),
                       value: configuration.isPressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hovering)
    }
}

// MARK: - Entry row

/// A saved word row with hover-reveal delete and a lighter soundsLike sub-line.
private struct EntryRow: View {
    let entry: DictionaryEntry
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.word)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.charcoal)
                if let alias = entry.soundsLike, !alias.isEmpty {
                    Text("sounds like \(alias)")
                        .font(.caption)
                        .foregroundStyle(Theme.charcoal.opacity(0.55))
                }
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.charcoal.opacity(0.6))
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .help("Remove this word")
        }
        .padding(12)
        .background(Theme.creamSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.gold.opacity(hovering ? 0.25 : 0), lineWidth: 1)
        )
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hovering)
    }
}

// MARK: - Flow layout

/// A simple wrapping layout for the suggestion chips so they flow onto new
/// lines and stay resize-safe.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var x: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                totalHeight += rowHeight + spacing
                rows.append([])
                x = 0
                rowHeight = 0
            }
            rows[rows.count - 1].append(size)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
