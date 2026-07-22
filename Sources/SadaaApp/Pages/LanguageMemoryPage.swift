import SwiftUI
import AppKit
import SadaaCore

struct LanguageMemoryPage: View {
    @ObservedObject var viewModel: LanguageMemoryViewModel

    @State private var section: DictionarySection = .words
    @State private var word = ""
    @State private var soundsLike = ""
    @State private var heard = ""
    @State private var replacement = ""
    @State private var snippetTrigger = ""
    @State private var snippetExpansion = ""
    @State private var showImport = false
    @State private var importKind: ImportKind = .json
    @State private var importText = ""
    @State private var importMessage = ""
    @State private var toast = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !viewModel.suggestions.isEmpty { suggestions }
                teachPanel
                sectionPicker
                entries
                shortcuts
                if !toast.isEmpty {
                    Text(toast)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.success)
                }
            }
            .padding(32)
            .frame(maxWidth: 900, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Theme.surface)
        .sheet(isPresented: $showImport) { importSheet }
    }

    private var header: some View {
        CommandPageHeader(
            title: "Dictionary",
            subtitle: "Words bias recognition. Corrections fix mistakes automatically. Once learned, the same error is fixed next time."
        ) {
            Menu {
                Button("Copy full backup") { copy(viewModel.exportSnapshotJSON()) }
                Button("Copy words as CSV") { copy(viewModel.exportTermsCSV()) }
                Button("Copy corrections as CSV") { copy(viewModel.exportReplacementsCSV()) }
                Divider()
                Button("Import dictionary") {
                    importText = ""
                    importMessage = ""
                    showImport = true
                }
            } label: {
                Label("Import and export", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 34)
            .help("Import and export")
            .clickableCursor()
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggested from recent use")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Review and add anything that should stay in your dictionary.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Text("\(viewModel.suggestions.count)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.brand)
            }

            ForEach(viewModel.filteredSuggestions.prefix(5)) { suggestion in
                HStack(spacing: 10) {
                    if suggestion.kind == .replacement,
                       !suggestion.observed.isEmpty,
                       suggestion.observed.caseInsensitiveCompare(suggestion.proposed) != .orderedSame {
                        Text(suggestion.observed)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.muted)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.muted)
                    }
                    Text(suggestion.proposed)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if suggestion.evidenceCount > 1 {
                        Text("×\(suggestion.evidenceCount)")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button("Dismiss") { viewModel.dismissSuggestion(suggestion.id) }
                        .buttonStyle(.borderless)
                        .clickableCursor()
                    Button("Add") { viewModel.acceptSuggestion(suggestion.id, as: suggestion.kind) }
                        .buttonStyle(.bordered)
                        .tint(Theme.brand)
                        .clickableCursor()
                }
                .padding(.vertical, 3)
            }
        }
        .padding(16)
        .background(Theme.surfaceSubtle, in: RoundedRectangle(cornerRadius: 12))
    }

    private var teachPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            CommandPanel("Add a word or name") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        TextField("Claude Code, Sadaa, Kubernetes", text: $word)
                            .premiumInputChrome()
                            .onSubmit { addWord() }
                        Button("Add") { addWord() }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.brand)
                            .controlSize(.large)
                            .clickableCursor()
                            .disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    TextField("Sounds like (optional, comma separated)", text: $soundsLike)
                        .premiumInputChrome()
                        .onSubmit { addWord() }
                    Text("Saved words are sent to Deepgram as keyterms and also force the correct spelling locally.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
            }

            CommandPanel("Fix a recurring mistake") {
                VStack(alignment: .leading, spacing: 10) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            TextField("When Sadaa hears", text: $heard)
                                .premiumInputChrome()
                            Image(systemName: "arrow.right")
                                .foregroundStyle(Theme.muted)
                            TextField("Write this instead", text: $replacement)
                                .premiumInputChrome()
                            Button("Learn") { addCorrection() }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.brand)
                                .controlSize(.large)
                                .clickableCursor()
                                .disabled(correctionDisabled)
                        }
                        VStack(spacing: 10) {
                            TextField("When Sadaa hears", text: $heard).premiumInputChrome()
                            TextField("Write this instead", text: $replacement).premiumInputChrome()
                            Button("Learn") { addCorrection() }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.brand)
                                .clickableCursor()
                                .disabled(correctionDisabled)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    Text("Creates an auto-correction and adds the correct word to your dictionary. The same mistake is fixed from the next dictation.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private var correctionDisabled: Bool {
        heard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sectionPicker: some View {
        HStack(spacing: 14) {
            Picker("Dictionary section", selection: $section) {
                ForEach(DictionarySection.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            .tint(Theme.brand)
            .clickableCursor()

            PremiumSearchField(placeholder: "Search dictionary", text: $viewModel.query)
                .frame(maxWidth: 320)
            Spacer()
        }
    }

    private var entries: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(section.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(entryCount)")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }

            switch section {
            case .words:
                if viewModel.filteredTerms.isEmpty {
                    emptyEntries("No saved words", "Add names, brands and specialist terms you want spelled exactly.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(viewModel.filteredTerms) { term in
                            MemoryTermRow(term: term) { viewModel.removeTerm(id: term.id) }
                        }
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
                }
            case .corrections:
                if viewModel.filteredReplacements.isEmpty {
                    emptyEntries("No auto-corrections yet", "Teach a mistake once. Sadaa applies it on every future dictation.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(viewModel.filteredReplacements) { rule in
                            ReplacementRuleRow(
                                rule: rule,
                                onToggleEnabled: {
                                    viewModel.setReplacementEnabled(rule.id, isEnabled: !rule.isEnabled)
                                },
                                onDelete: { viewModel.removeReplacement(id: rule.id) }
                            )
                        }
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
                }
            }
        }
    }

    private var entryCount: Int {
        section == .words ? viewModel.filteredTerms.count : viewModel.filteredReplacements.count
    }

    private var shortcuts: some View {
        DisclosureGroup("Text shortcuts") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Say a short trigger and expand it into reusable text.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)

                HStack(spacing: 10) {
                    TextField("Trigger", text: $snippetTrigger).premiumInputChrome()
                    TextField("Expanded text", text: $snippetExpansion).premiumInputChrome()
                    Button("Add") {
                        viewModel.addSnippet(trigger: snippetTrigger, expansion: snippetExpansion)
                        snippetTrigger = ""
                        snippetExpansion = ""
                        flash("Shortcut saved.")
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.brand)
                    .clickableCursor()
                    .disabled(snippetTrigger.isEmpty || snippetExpansion.isEmpty)
                }

                ForEach(viewModel.filteredSnippets) { snippet in
                    MemorySnippetRow(
                        snippet: snippet,
                        onToggleEnabled: {
                            viewModel.setSnippetEnabled(snippet.id, isEnabled: !snippet.isEnabled)
                        },
                        onDelete: { viewModel.removeSnippet(id: snippet.id) }
                    )
                }
            }
            .padding(.top, 12)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.ink)
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
    }

    private var importSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import dictionary")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.ink)
            Picker("Format", selection: $importKind) {
                ForEach(ImportKind.allCases) { kind in Text(kind.title).tag(kind) }
            }
            .pickerStyle(.segmented)
            .tint(Theme.brand)
            .clickableCursor()

            TextEditor(text: $importText)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Theme.surfaceSubtle, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line, lineWidth: 1))
                .frame(minHeight: 230)

            if !importMessage.isEmpty {
                Text(importMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(importMessage.hasPrefix("Imported") ? Theme.success : Theme.danger)
            }

            HStack {
                Spacer()
                Button("Cancel") { showImport = false }
                    .clickableCursor()
                Button("Import") { performImport() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brand)
                    .clickableCursor()
                    .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 560, height: 420)
        .background(Theme.surface)
    }

    private func emptyEntries(_ title: String, _ detail: String) -> some View {
        CommandEmptyState(icon: "character.book.closed", title: title, detail: detail)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
    }

    private func addWord() {
        let phrase = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return }
        let pronunciations = split(soundsLike)
        viewModel.addTerm(
            phrase: phrase,
            pronunciations: pronunciations,
            aliases: [],
            priority: .high,
            language: .auto,
            notes: ""
        )
        word = ""
        soundsLike = ""
        section = .words
        if pronunciations.isEmpty {
            flash("Added “\(phrase)”. It will bias the next dictation and fix its own casing.")
        } else {
            flash("Added “\(phrase)” with \(pronunciations.count) sound-alike fix\(pronunciations.count == 1 ? "" : "es").")
        }
    }

    private func addCorrection() {
        let result = viewModel.learnCorrection(observed: heard, corrected: replacement)
        guard !result.pairs.isEmpty else { return }
        heard = ""
        replacement = ""
        section = .corrections
        let n = result.replacementCount
        if n == 0 {
            flash("Saved as a dictionary word.")
        } else {
            flash("Learned \(n) auto-correction\(n == 1 ? "" : "s"). Same mistake will be fixed next time.")
        }
    }

    private func performImport() {
        switch importKind {
        case .json:
            guard let result = viewModel.importSnapshotJSON(importText) else {
                importMessage = "The JSON backup could not be read."
                return
            }
            importMessage = resultMessage(result)
        case .wordsCSV:
            importMessage = resultMessage(viewModel.importTermsCSV(importText))
        case .correctionsCSV:
            importMessage = resultMessage(viewModel.importReplacementsCSV(importText))
        }
    }

    private func resultMessage(_ result: LanguageMemoryImportResult) -> String {
        "Imported \(result.inserted) new and updated \(result.updated). \(result.duplicates) duplicates skipped."
    }

    private func split(_ value: String) -> [String] {
        value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func flash(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if toast == message { toast = "" }
        }
    }
}

private enum DictionarySection: String, CaseIterable, Identifiable {
    case words, corrections
    var id: String { rawValue }
    var title: String {
        switch self {
        case .words: return "Words"
        case .corrections: return "Auto-corrections"
        }
    }
}

private enum ImportKind: String, CaseIterable, Identifiable {
    case json, wordsCSV, correctionsCSV
    var id: String { rawValue }
    var title: String {
        switch self {
        case .json: return "Full backup"
        case .wordsCSV: return "Words CSV"
        case .correctionsCSV: return "Corrections CSV"
        }
    }
}
