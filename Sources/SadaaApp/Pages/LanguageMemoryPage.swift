import SwiftUI
import AppKit
import SadaaCore

struct LanguageMemoryPage: View {
    @ObservedObject var viewModel: LanguageMemoryViewModel

    @State private var tab: MemoryTab = .terms
    @State private var termPhrase = ""
    @State private var termPronunciations = ""
    @State private var termAliases = ""
    @State private var termNotes = ""
    @State private var termPriority: MemoryPriority = .high
    @State private var termLanguage: MemoryLanguage = .auto
    @State private var replacementMatch = ""
    @State private var replacementValue = ""
    @State private var replacementMode: ReplacementMatchMode = .wordBoundaryPhrase
    @State private var replacementLanguage: MemoryLanguage = .auto
    @State private var replacementPreviewText = ""
    @State private var snippetTrigger = ""
    @State private var snippetExpansion = ""
    @State private var snippetTags = ""
    @State private var snippetLanguage: MemoryLanguage = .auto
    @State private var showImport = false
    @State private var importKind: MemoryImportKind = .json
    @State private var importText = ""
    @State private var importError = ""
    @State private var copiedExport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            PremiumSearchField(placeholder: "Search terms, replacements, snippets", text: $viewModel.query)
                .frame(maxWidth: 560)
            Picker("", selection: $tab) {
                ForEach(MemoryTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 560)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch tab {
                    case .terms:
                        termComposer
                        termList
                    case .replacements:
                        replacementComposer
                        replacementList
                    case .snippets:
                        snippetComposer
                        snippetList
                    case .suggestions:
                        suggestionList
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.bottom, 20)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showImport) { importSheet }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Language Memory")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.charcoal)
            HStack(spacing: 8) {
                PremiumStatusBadge(icon: "textformat", text: "\(viewModel.terms.count) terms", tint: Theme.navy)
                PremiumStatusBadge(icon: "arrow.left.arrow.right", text: "\(viewModel.replacements.count) replacements", tint: Theme.sage)
                PremiumStatusBadge(icon: "text.badge.plus", text: "\(viewModel.snippets.count) snippets", tint: Theme.gold)
                PremiumStatusBadge(icon: "sparkles", text: "\(viewModel.suggestions.count) suggestions", tint: Theme.navy)
                Spacer(minLength: 8)
                Menu {
                    Button("Copy JSON") { copyExport(.json) }
                    Button("Copy terms CSV") { copyExport(.termsCSV) }
                    Button("Copy replacements CSV") { copyExport(.replacementsCSV) }
                } label: {
                    Image(systemName: copiedExport ? "checkmark" : "square.and.arrow.up")
                }
                .buttonStyle(PremiumIconButtonStyle())
                .help("Copy Language Memory export")
                Menu {
                    Button("Import JSON") { beginImport(.json) }
                    Button("Import terms CSV") { beginImport(.termsCSV) }
                    Button("Import replacements CSV") { beginImport(.replacementsCSV) }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(PremiumIconButtonStyle())
                .help("Import Language Memory")
            }
            .frame(maxWidth: 720)
        }
    }

    private var importSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Language Memory")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.charcoal)
            Picker("", selection: $importKind) {
                ForEach(MemoryImportKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            TextEditor(text: $importText)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 220)
                .padding(8)
                .background(Theme.creamSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1)
                )
            if !importError.isEmpty {
                Text(importError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { showImport = false }
                Button("Import") {
                    guard let result = importMemory() else { return }
                    importError = "Imported \(result.inserted) items, updated \(result.updated)."
                    showImport = false
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.navy)
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 560)
    }

    private var termComposer: some View {
        PremiumSection("Teach Sadaa a term", icon: "textformat") {
            TextField("Phrase, name, acronym, product", text: $termPhrase)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                TextField("Pronunciations, comma separated", text: $termPronunciations)
                    .textFieldStyle(.roundedBorder)
                TextField("Aliases, comma separated", text: $termAliases)
                    .textFieldStyle(.roundedBorder)
            }
            TextField("Notes", text: $termNotes)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                Picker("Priority", selection: $termPriority) {
                    ForEach(MemoryPriority.allCases, id: \.self) { priority in
                        Text(priorityTitle(priority)).tag(priority)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Language", selection: $termLanguage) {
                    ForEach(MemoryLanguage.allCases, id: \.self) { language in
                        Text(languageTitle(language)).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }
            Button {
                viewModel.addTerm(
                    phrase: termPhrase,
                    pronunciations: split(termPronunciations),
                    aliases: split(termAliases),
                    priority: termPriority,
                    language: termLanguage,
                    notes: termNotes
                )
                termPhrase = ""
                termPronunciations = ""
                termAliases = ""
                termNotes = ""
                termPriority = .high
                termLanguage = .auto
            } label: {
                Label("Add term", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.navy)
            .disabled(termPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var replacementComposer: some View {
        PremiumSection("Create a deterministic correction", icon: "arrow.left.arrow.right") {
            HStack(spacing: 8) {
                TextField("When Sadaa hears", text: $replacementMatch)
                    .textFieldStyle(.roundedBorder)
                TextField("Write this", text: $replacementValue)
                    .textFieldStyle(.roundedBorder)
            }
            Picker("Match", selection: $replacementMode) {
                Text("Exact").tag(ReplacementMatchMode.exactPhrase)
                Text("Case-insensitive").tag(ReplacementMatchMode.caseInsensitivePhrase)
                Text("Word boundary").tag(ReplacementMatchMode.wordBoundaryPhrase)
            }
            .pickerStyle(.segmented)
            Picker("Language", selection: $replacementLanguage) {
                ForEach(MemoryLanguage.allCases, id: \.self) { language in
                    Text(languageTitle(language)).tag(language)
                }
            }
            .pickerStyle(.segmented)
            TextField("Preview on sample text", text: $replacementPreviewText)
                .textFieldStyle(.roundedBorder)
            if let replacementPreview {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(Theme.gold)
                    Text(replacementPreview)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.charcoal)
                        .lineLimit(3)
                }
                .padding(10)
                .background(Theme.cream, in: RoundedRectangle(cornerRadius: 8))
            }
            Button {
                viewModel.addReplacement(
                    match: replacementMatch,
                    replacement: replacementValue,
                    mode: replacementMode,
                    language: replacementLanguage
                )
                replacementMatch = ""
                replacementValue = ""
                replacementLanguage = .auto
                replacementPreviewText = ""
            } label: {
                Label("Add replacement", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.navy)
            .disabled(replacementMatch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                      replacementValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var snippetComposer: some View {
        PremiumSection("Create a spoken snippet", icon: "text.badge.plus") {
            HStack(spacing: 8) {
                TextField("Trigger, e.g. my signature", text: $snippetTrigger)
                    .textFieldStyle(.roundedBorder)
                TextField("Tags", text: $snippetTags)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
            }
            Picker("Language", selection: $snippetLanguage) {
                ForEach(MemoryLanguage.allCases, id: \.self) { language in
                    Text(languageTitle(language)).tag(language)
                }
            }
            .pickerStyle(.segmented)
            TextEditor(text: $snippetExpansion)
                .font(.system(size: 12))
                .frame(minHeight: 74)
                .padding(6)
                .background(Theme.cream)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1))
            Button {
                viewModel.addSnippet(
                    trigger: snippetTrigger,
                    expansion: snippetExpansion,
                    tags: split(snippetTags),
                    language: snippetLanguage
                )
                snippetTrigger = ""
                snippetExpansion = ""
                snippetTags = ""
                snippetLanguage = .auto
            } label: {
                Label("Add snippet", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.navy)
            .disabled(snippetTrigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                      snippetExpansion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var termList: some View {
        VStack(spacing: 8) {
            if viewModel.filteredTerms.isEmpty {
                empty("No saved terms yet.", icon: "textformat")
            } else {
                ForEach(viewModel.filteredTerms) { term in
                    MemoryTermRow(term: term) {
                        viewModel.removeTerm(id: term.id)
                    }
                }
            }
        }
    }

    private var replacementList: some View {
        VStack(spacing: 8) {
            if viewModel.filteredReplacements.isEmpty {
                empty("No replacements yet.", icon: "arrow.left.arrow.right")
            } else {
                ForEach(viewModel.filteredReplacements) { rule in
                    ReplacementRuleRow(
                        rule: rule,
                        onToggleEnabled: {
                            viewModel.setReplacementEnabled(rule.id, isEnabled: !rule.isEnabled)
                        },
                        onDelete: {
                            viewModel.removeReplacement(id: rule.id)
                        }
                    )
                }
            }
        }
    }

    private var replacementPreview: String? {
        let sample = replacementPreviewText.trimmingCharacters(in: .whitespacesAndNewlines)
        let match = replacementMatch.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = replacementValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sample.isEmpty, !match.isEmpty, !value.isEmpty else { return nil }
        let rule = ReplacementRule(
            match: match,
            replacement: value,
            matchMode: replacementMode,
            language: replacementLanguage
        )
        return ReplacementEngine.apply([rule], to: sample, language: replacementLanguage).text
    }

    private var snippetList: some View {
        VStack(spacing: 8) {
            if viewModel.filteredSnippets.isEmpty {
                empty("No snippets yet.", icon: "text.badge.plus")
            } else {
                ForEach(viewModel.filteredSnippets) { snippet in
                    MemorySnippetRow(
                        snippet: snippet,
                        onToggleEnabled: {
                            viewModel.setSnippetEnabled(snippet.id, isEnabled: !snippet.isEnabled)
                        },
                        onDelete: {
                            viewModel.removeSnippet(id: snippet.id)
                        }
                    )
                }
            }
        }
    }

    private var suggestionList: some View {
        VStack(spacing: 8) {
            if viewModel.filteredSuggestions.isEmpty {
                empty("No suggestions waiting.", icon: "sparkles")
            } else {
                ForEach(viewModel.filteredSuggestions) { suggestion in
                    MemorySuggestionRow(
                        suggestion: suggestion,
                        onAccept: { viewModel.acceptSuggestion(suggestion.id, as: suggestion.kind) },
                        onDismiss: { viewModel.dismissSuggestion(suggestion.id) }
                    )
                }
            }
        }
    }

    private func empty(_ text: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.gold300)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.charcoal.opacity(0.58))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    private func split(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func languageTitle(_ language: MemoryLanguage) -> String {
        switch language {
        case .auto: return "Any language"
        case .en: return "English"
        case .de: return "German"
        }
    }

    private func priorityTitle(_ priority: MemoryPriority) -> String {
        switch priority {
        case .normal: return "Normal"
        case .high: return "High"
        case .always: return "Always"
        }
    }

    private func beginImport(_ kind: MemoryImportKind) {
        importKind = kind
        importText = ""
        importError = ""
        showImport = true
    }

    private func importMemory() -> LanguageMemoryImportResult? {
        switch importKind {
        case .json:
            guard let result = viewModel.importSnapshotJSON(importText) else {
                importError = "Paste a valid Language Memory JSON export."
                return nil
            }
            return result
        case .termsCSV:
            let result = viewModel.importTermsCSV(importText)
            if result.inserted == 0, result.updated == 0, !result.invalid.isEmpty {
                importError = "No valid term rows found."
                return nil
            }
            return result
        case .replacementsCSV:
            let result = viewModel.importReplacementsCSV(importText)
            if result.inserted == 0, result.updated == 0, !result.invalid.isEmpty {
                importError = "No valid replacement rows found."
                return nil
            }
            return result
        }
    }

    private func copyExport(_ kind: MemoryImportKind) {
        let export: String
        switch kind {
        case .json:
            export = viewModel.exportSnapshotJSON()
        case .termsCSV:
            export = viewModel.exportTermsCSV()
        case .replacementsCSV:
            export = viewModel.exportReplacementsCSV()
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(export, forType: .string)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { copiedExport = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { copiedExport = false }
        }
    }
}

private enum MemoryImportKind: String, CaseIterable, Identifiable {
    case json, termsCSV, replacementsCSV

    var id: String { rawValue }

    var title: String {
        switch self {
        case .json: return "JSON"
        case .termsCSV: return "Terms CSV"
        case .replacementsCSV: return "Replacements CSV"
        }
    }
}

private enum MemoryTab: String, CaseIterable, Identifiable {
    case terms, replacements, snippets, suggestions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: return "Terms"
        case .replacements: return "Replacements"
        case .snippets: return "Snippets"
        case .suggestions: return "Suggestions"
        }
    }
}
