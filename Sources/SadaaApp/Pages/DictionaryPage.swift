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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Dictionary")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.charcoal)

                if !viewModel.dictionarySuggestions.isEmpty {
                    suggestionsSection
                }

                addSection
                entriesSection
                snippetsSection
            }
            .padding(32)
            .frame(maxWidth: 620, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggestions")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.charcoal)
            Text("Terms Sadaa had to guess. Accept the ones worth keeping.")
                .font(.caption)
                .foregroundStyle(Theme.charcoal.opacity(0.6))

            ForEach(viewModel.dictionarySuggestions, id: \.self) { term in
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.gold)
                    Text(term)
                        .foregroundStyle(Theme.charcoal)
                    Spacer()
                    Button("Add") { viewModel.acceptSuggestion(term) }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.sage)
                    Button("Dismiss") { viewModel.dismissSuggestion(term) }
                        .buttonStyle(.bordered)
                }
                .padding(12)
                .background(Theme.creamSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Add

    private var addSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add a word")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.charcoal)
            HStack(spacing: 8) {
                TextField("Word (e.g. Karko AI)", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                TextField("Sounds like (optional)", text: $newSoundsLike)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { add() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.navy)
                    .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func add() {
        let word = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        viewModel.addDictionaryWord(word, soundsLike: newSoundsLike
            .trimmingCharacters(in: .whitespacesAndNewlines))
        newWord = ""
        newSoundsLike = ""
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
                        viewModel.removeSnippet(snippet.id)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Theme.charcoal.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Theme.creamSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func addSnippet() {
        viewModel.addSnippet(
            trigger: newTrigger.trimmingCharacters(in: .whitespacesAndNewlines),
            expansion: newExpansion.trimmingCharacters(in: .whitespacesAndNewlines))
        newTrigger = ""
        newExpansion = ""
    }

    // MARK: - Entries

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your words")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.charcoal)

            if viewModel.dictionaryEntries.isEmpty {
                Text("No words yet. Add the names and jargon Sadaa keeps getting wrong.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.charcoal.opacity(0.6))
            } else {
                ForEach(viewModel.dictionaryEntries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.word)
                                .foregroundStyle(Theme.charcoal)
                            if let alias = entry.soundsLike, !alias.isEmpty {
                                Text("sounds like \(alias)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.charcoal.opacity(0.55))
                            }
                        }
                        Spacer()
                        Button {
                            viewModel.removeDictionaryEntry(entry.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Theme.charcoal.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Theme.creamSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}
