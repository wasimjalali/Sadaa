import SwiftUI
import AppKit
import SadaaCore

struct LanguageMemoryPage: View {
    @ObservedObject var viewModel: LanguageMemoryViewModel

    @State private var mode: MemoryMode = .terms
    @State private var termPhrase = ""
    @State private var termPronunciations = ""
    @State private var termAliases = ""
    @State private var termNotes = ""
    @State private var termPriority: MemoryPriority = .high
    @State private var termLanguage: MemoryLanguage = .auto
    @State private var correctionHeard = ""
    @State private var correctionWrite = ""
    @State private var correctionMode: ReplacementMatchMode = .wordBoundaryPhrase
    @State private var correctionLanguage: MemoryLanguage = .auto
    @State private var correctionPreviewText = ""
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
        VStack(alignment: .leading, spacing: 20) {
            header
            workbench
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.cream)
        .sheet(isPresented: $showImport) { importSheet }
    }

    private var header: some View {
        CommandPageHeader(
            eyebrow: "Learning system",
            title: "Memory",
            subtitle: "Teach Sadaa exact AI terms, deterministic corrections, snippets, and learning signals."
        ) {
            HStack(spacing: 8) {
                exportMenu
                importMenu
            }
        }
    }

    private var workbench: some View {
        HStack(alignment: .top, spacing: 16) {
            rail
                .frame(width: 250)
            listPanel
                .frame(minWidth: 360, maxWidth: .infinity)
            inspector
                .frame(width: 330)
        }
    }

    private var rail: some View {
        CommandPanel {
            VStack(alignment: .leading, spacing: 14) {
                PremiumSearchField(
                    placeholder: "Search memory",
                    text: $viewModel.query
                )
                Picker("", selection: $mode) {
                    ForEach(MemoryMode.allCases) { item in
                        Text(item.shortTitle).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .tint(Theme.navy)
                .accentColor(Theme.navy)
                VStack(spacing: 10) {
                    CommandMetric(icon: "textformat", value: "\(viewModel.terms.count)", label: "terms", tint: Theme.navy)
                    CommandMetric(icon: "arrow.left.arrow.right", value: "\(viewModel.replacements.count)", label: "corrections", tint: Theme.sage)
                    CommandMetric(icon: "text.badge.plus", value: "\(viewModel.snippets.count)", label: "snippets", tint: Theme.gold)
                    CommandMetric(icon: "sparkles", value: "\(viewModel.suggestions.count)", label: "learning queue", tint: Theme.navy)
                }
                Divider()
                Text("Corrections are local and deterministic. If Sadaa hears the same mistake again, this layer fixes it before and after GPT formatting.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var listPanel: some View {
        CommandPanel(mode.title, icon: mode.icon) {
            ScrollView {
                VStack(spacing: 10) {
                    switch mode {
                    case .terms:
                        termList
                    case .corrections:
                        correctionList
                    case .snippets:
                        snippetList
                    case .learning:
                        suggestionList
                    }
                }
                .padding(.bottom, 4)
            }
            .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var inspector: some View {
        switch mode {
        case .terms:
            termComposer
        case .corrections:
            correctionComposer
        case .snippets:
            snippetComposer
        case .learning:
            learningInspector
        }
    }

    private var termComposer: some View {
        CommandPanel("Add term", icon: "textformat") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Phrase, name, acronym, product", text: $termPhrase)
                    .textFieldStyle(.roundedBorder)
                TextField("Pronunciations, comma separated", text: $termPronunciations)
                    .textFieldStyle(.roundedBorder)
                TextField("Aliases, comma separated", text: $termAliases)
                    .textFieldStyle(.roundedBorder)
                TextField("Notes", text: $termNotes)
                    .textFieldStyle(.roundedBorder)
                Picker("Priority", selection: $termPriority) {
                    ForEach(MemoryPriority.allCases, id: \.self) { priority in
                        Text(priorityTitle(priority)).tag(priority)
                    }
                }
                .pickerStyle(.segmented)
                .tint(Theme.navy)
                .accentColor(Theme.navy)
                Picker("Language", selection: $termLanguage) {
                    ForEach(MemoryLanguage.allCases, id: \.self) { language in
                        Text(languageTitle(language)).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .tint(Theme.navy)
                .accentColor(Theme.navy)
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
    }

    private var correctionComposer: some View {
        CommandPanel("Add correction", icon: "arrow.left.arrow.right") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("When Sadaa hears", text: $correctionHeard)
                    .textFieldStyle(.roundedBorder)
                TextField("Write this", text: $correctionWrite)
                    .textFieldStyle(.roundedBorder)
                Picker("Match", selection: $correctionMode) {
                    Text("Exact").tag(ReplacementMatchMode.exactPhrase)
                    Text("Case").tag(ReplacementMatchMode.caseInsensitivePhrase)
                    Text("Boundary").tag(ReplacementMatchMode.wordBoundaryPhrase)
                }
                .pickerStyle(.segmented)
                .tint(Theme.navy)
                .accentColor(Theme.navy)
                Picker("Language", selection: $correctionLanguage) {
                    ForEach(MemoryLanguage.allCases, id: \.self) { language in
                        Text(languageTitle(language)).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .tint(Theme.navy)
                .accentColor(Theme.navy)
                TextField("Preview on sample text", text: $correctionPreviewText)
                    .textFieldStyle(.roundedBorder)
                if let correctionPreview {
                    previewBox(correctionPreview)
                }
                Button {
                    viewModel.addReplacement(
                        match: correctionHeard,
                        replacement: correctionWrite,
                        mode: correctionMode,
                        language: correctionLanguage
                    )
                    correctionHeard = ""
                    correctionWrite = ""
                    correctionLanguage = .auto
                    correctionPreviewText = ""
                } label: {
                    Label("Add correction", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.navy)
                .disabled(correctionHeard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          correctionWrite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var snippetComposer: some View {
        CommandPanel("Add snippet", icon: "text.badge.plus") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Trigger, e.g. my signature", text: $snippetTrigger)
                    .textFieldStyle(.roundedBorder)
                TextField("Tags, comma separated", text: $snippetTags)
                    .textFieldStyle(.roundedBorder)
                Picker("Language", selection: $snippetLanguage) {
                    ForEach(MemoryLanguage.allCases, id: \.self) { language in
                        Text(languageTitle(language)).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .tint(Theme.navy)
                .accentColor(Theme.navy)
                TextEditor(text: $snippetExpansion)
                    .font(.system(size: 12))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Theme.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
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
    }

    private var learningInspector: some View {
        CommandPanel("How Memory learns", icon: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                learningStep("1", "Formatter finds unusual AI terms.")
                learningStep("2", "History corrections become deterministic rules.")
                learningStep("3", "Accepted queue items stop repeated mistakes.")
                Divider()
                Text("Use History or Home's Learn action when Sadaa misses a name, framework, acronym, or phrase. Corrections are stronger than terms.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func learningStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.navy)
                .frame(width: 22, height: 22)
                .background(Theme.gold.opacity(0.18), in: Circle())
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var termList: some View {
        if viewModel.filteredTerms.isEmpty {
            CommandEmptyState(icon: "textformat", title: "No terms yet", detail: "Add names, products, APIs, and acronyms Sadaa must spell correctly.")
        } else {
            ForEach(viewModel.filteredTerms) { term in
                MemoryTermRow(term: term) {
                    viewModel.removeTerm(id: term.id)
                }
            }
        }
    }

    @ViewBuilder
    private var correctionList: some View {
        if viewModel.filteredReplacements.isEmpty {
            CommandEmptyState(icon: "arrow.left.arrow.right", title: "No corrections yet", detail: "Create deterministic fixes such as cloud code -> Claude Code.")
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

    @ViewBuilder
    private var snippetList: some View {
        if viewModel.filteredSnippets.isEmpty {
            CommandEmptyState(icon: "text.badge.plus", title: "No snippets yet", detail: "Add spoken shortcuts for reusable replies, signatures, and AI workflow text.")
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

    @ViewBuilder
    private var suggestionList: some View {
        if viewModel.filteredSuggestions.isEmpty {
            CommandEmptyState(icon: "sparkles", title: "Learning queue is clear", detail: "New terms and correction candidates appear here as evidence builds.")
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

    private var correctionPreview: String? {
        let sample = correctionPreviewText.trimmingCharacters(in: .whitespacesAndNewlines)
        let match = correctionHeard.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = correctionWrite.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sample.isEmpty, !match.isEmpty, !value.isEmpty else { return nil }
        let rule = ReplacementRule(
            match: match,
            replacement: value,
            matchMode: correctionMode,
            language: correctionLanguage
        )
        return ReplacementEngine.apply([rule], to: sample, language: correctionLanguage).text
    }

    private func previewBox(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(Theme.gold)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(4)
        }
        .padding(10)
        .background(Theme.gold.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.gold.opacity(0.2), lineWidth: 1))
    }

    private var importSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            CommandPageHeader(
                eyebrow: "Memory",
                title: "Import",
                subtitle: "Paste a local Memory export or CSV. Matching entries are updated."
            )
            Picker("", selection: $importKind) {
                ForEach(MemoryImportKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .tint(Theme.navy)
            .accentColor(Theme.navy)
            TextEditor(text: $importText)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 220)
                .padding(8)
                .background(Theme.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
            if !importError.isEmpty {
                Text(importError)
                    .font(.caption)
                    .foregroundStyle(Theme.red)
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
        .padding(24)
        .frame(width: 580)
        .background(Theme.cream)
    }

    private var exportMenu: some View {
        Menu {
            Button("Copy JSON") { copyExport(.json) }
            Button("Copy terms CSV") { copyExport(.termsCSV) }
            Button("Copy corrections CSV") { copyExport(.replacementsCSV) }
        } label: {
            Image(systemName: copiedExport ? "checkmark" : "square.and.arrow.up")
        }
        .buttonStyle(PremiumIconButtonStyle())
        .help("Copy Memory export")
    }

    private var importMenu: some View {
        Menu {
            Button("Import JSON") { beginImport(.json) }
            Button("Import terms CSV") { beginImport(.termsCSV) }
            Button("Import corrections CSV") { beginImport(.replacementsCSV) }
        } label: {
            Image(systemName: "square.and.arrow.down")
        }
        .buttonStyle(PremiumIconButtonStyle())
        .help("Import Memory")
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
                importError = "Paste a valid Memory JSON export."
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
                importError = "No valid correction rows found."
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { copiedExport = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { copiedExport = false }
        }
    }

    private func split(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func languageTitle(_ language: MemoryLanguage) -> String {
        switch language {
        case .auto: return "Any"
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
}

private enum MemoryMode: String, CaseIterable, Identifiable {
    case terms, corrections, snippets, learning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: return "Terms"
        case .corrections: return "Corrections"
        case .snippets: return "Snippets"
        case .learning: return "Learning Queue"
        }
    }

    var shortTitle: String {
        switch self {
        case .terms: return "Terms"
        case .corrections: return "Fixes"
        case .snippets: return "Snips"
        case .learning: return "Queue"
        }
    }

    var icon: String {
        switch self {
        case .terms: return "textformat"
        case .corrections: return "arrow.left.arrow.right"
        case .snippets: return "text.badge.plus"
        case .learning: return "sparkles"
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
        case .replacementsCSV: return "Corrections CSV"
        }
    }
}
