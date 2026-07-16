import SwiftUI
import AppKit
import SadaaCore

struct LanguageMemoryPage: View {
    @ObservedObject var viewModel: LanguageMemoryViewModel

    @State private var section: DictionarySection = .words
    @State private var word = ""
    @State private var pronunciations = ""
    @State private var aliases = ""
    @State private var notes = ""
    @State private var priority: MemoryPriority = .high
    @State private var wordLanguage: MemoryLanguage = .auto
    @State private var heard = ""
    @State private var replacement = ""
    @State private var replacementLanguage: MemoryLanguage = .auto
    @State private var matchMode: ReplacementMatchMode = .wordBoundaryPhrase
    @State private var snippetTrigger = ""
    @State private var snippetExpansion = ""
    @State private var showImport = false
    @State private var importKind: ImportKind = .json
    @State private var importText = ""
    @State private var importMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if !viewModel.suggestions.isEmpty { suggestions }
                sectionPicker
                quickAdd
                entries
                shortcuts
            }
            .padding(32)
            .frame(maxWidth: 980, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Theme.surface)
        .sheet(isPresented: $showImport) { importSheet }
    }

    private var header: some View {
        CommandPageHeader(
            title: "Dictionary",
            subtitle: "Teach Sadaa the exact words, names and corrections that matter to you."
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
                    Text("Suggestions to review")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Sadaa noticed these spellings in recent corrections.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Text("\(viewModel.suggestions.count)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.brand)
            }

            ForEach(viewModel.filteredSuggestions.prefix(3)) { suggestion in
                HStack(spacing: 10) {
                    Text(suggestion.proposed)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.ink)
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

    private var sectionPicker: some View {
        HStack(spacing: 14) {
            Picker("Dictionary section", selection: $section) {
                ForEach(DictionarySection.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            .tint(Theme.brand)

            PremiumSearchField(placeholder: "Search dictionary", text: $viewModel.query)
                .frame(maxWidth: 360)
            Spacer()
        }
    }

    @ViewBuilder
    private var quickAdd: some View {
        switch section {
        case .words: addWordPanel
        case .corrections: addCorrectionPanel
        }
    }

    private var addWordPanel: some View {
        CommandPanel("Add a word or name") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TextField("Claude Code, Sadaa, MCP", text: $word)
                        .premiumInputChrome()
                    Button("Add word") { addWord() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.brand)
                        .controlSize(.large)
                        .clickableCursor()
                        .disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                DisclosureGroup("Advanced spelling help") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Sounds like, comma separated", text: $pronunciations)
                            .premiumInputChrome()
                        TextField("Alternative spellings, comma separated", text: $aliases)
                            .premiumInputChrome()
                        TextField("Optional note", text: $notes)
                            .premiumInputChrome()
                        HStack(spacing: 12) {
                            Picker("Priority", selection: $priority) {
                                Text("Normal").tag(MemoryPriority.normal)
                                Text("High").tag(MemoryPriority.high)
                                Text("Always").tag(MemoryPriority.always)
                            }
                            Picker("Language", selection: $wordLanguage) {
                                Text("Any language").tag(MemoryLanguage.auto)
                                Text("English").tag(MemoryLanguage.en)
                                Text("German").tag(MemoryLanguage.de)
                            }
                        }
                    }
                    .padding(.top, 10)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.muted)
            }
        }
    }

    private var addCorrectionPanel: some View {
        CommandPanel("Add an auto-correction") {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        TextField("When Sadaa hears", text: $heard)
                            .premiumInputChrome()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(Theme.muted)
                        TextField("Write this instead", text: $replacement)
                            .premiumInputChrome()
                        addCorrectionButton
                    }
                    VStack(spacing: 10) {
                        TextField("When Sadaa hears", text: $heard).premiumInputChrome()
                        TextField("Write this instead", text: $replacement).premiumInputChrome()
                        addCorrectionButton.frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                DisclosureGroup("Advanced matching") {
                    HStack(spacing: 12) {
                        Picker("Match", selection: $matchMode) {
                            Text("Word boundary").tag(ReplacementMatchMode.wordBoundaryPhrase)
                            Text("Case-insensitive").tag(ReplacementMatchMode.caseInsensitivePhrase)
                            Text("Exact phrase").tag(ReplacementMatchMode.exactPhrase)
                        }
                        Picker("Language", selection: $replacementLanguage) {
                            Text("Any language").tag(MemoryLanguage.auto)
                            Text("English").tag(MemoryLanguage.en)
                            Text("German").tag(MemoryLanguage.de)
                        }
                    }
                    .padding(.top, 10)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.muted)
            }
        }
    }

    private var addCorrectionButton: some View {
        Button("Add correction") { addCorrection() }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand)
            .controlSize(.large)
            .clickableCursor()
            .disabled(
                heard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
    }

    private var entries: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(section == .words ? "Saved words" : "Saved corrections")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(section == .words ? viewModel.filteredTerms.count : viewModel.filteredReplacements.count)")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }

            if section == .words {
                if viewModel.filteredTerms.isEmpty {
                    emptyEntries("No saved words", "Add names, acronyms and specialist terms you want spelled exactly.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(viewModel.filteredTerms) { term in
                            MemoryTermRow(term: term) { viewModel.removeTerm(id: term.id) }
                        }
                    }
                }
            } else if viewModel.filteredReplacements.isEmpty {
                emptyEntries("No auto-corrections", "Add a correction when Sadaa repeatedly hears the wrong phrase.")
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
            }
        }
    }

    private var shortcuts: some View {
        DisclosureGroup("Text shortcuts") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Say a short trigger and expand it into reusable text. This is optional and stays out of the main dictionary workflow.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)

                HStack(spacing: 10) {
                    TextField("Trigger", text: $snippetTrigger).premiumInputChrome()
                    TextField("Expanded text", text: $snippetExpansion).premiumInputChrome()
                    Button("Add shortcut") {
                        viewModel.addSnippet(trigger: snippetTrigger, expansion: snippetExpansion)
                        snippetTrigger = ""
                        snippetExpansion = ""
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
        viewModel.addTerm(
            phrase: word,
            pronunciations: split(pronunciations),
            aliases: split(aliases),
            priority: priority,
            language: wordLanguage,
            notes: notes
        )
        word = ""
        pronunciations = ""
        aliases = ""
        notes = ""
        priority = .high
        wordLanguage = .auto
    }

    private func addCorrection() {
        viewModel.addReplacement(
            match: heard,
            replacement: replacement,
            mode: matchMode,
            language: replacementLanguage
        )
        heard = ""
        replacement = ""
        matchMode = .wordBoundaryPhrase
        replacementLanguage = .auto
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
}

private enum DictionarySection: String, CaseIterable, Identifiable {
    case words, corrections
    var id: String { rawValue }
    var title: String { self == .words ? "Words and names" : "Auto-corrections" }
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
