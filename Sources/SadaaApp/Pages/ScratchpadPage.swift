import SwiftUI
import AppKit
import SadaaCore

struct ScratchpadPage: View {
    @ObservedObject var viewModel: SadaaViewModel
    @ObservedObject var scratchpad: ScratchpadViewModel
    @State private var showImport = false
    @State private var importText = ""
    @State private var importError = ""

    init(viewModel: SadaaViewModel) {
        self.viewModel = viewModel
        self.scratchpad = viewModel.scratchpad
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            workspace
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.cream)
        .sheet(isPresented: $showImport) {
            importSheet
        }
    }

    private var header: some View {
        CommandPageHeader(
            eyebrow: "Dictated thinking",
            title: "Scratchpad",
            subtitle: "A local writing desk for dictated notes, AI workflow fragments, and reusable thinking."
        ) {
            Button {
                _ = scratchpad.createNote(title: "Untitled", body: " ")
            } label: {
                Label("New note", systemImage: "square.and.pencil")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.navy)
        }
    }

    private var workspace: some View {
        HStack(alignment: .top, spacing: 16) {
            noteRail
                .frame(width: 300)
            editor
                .frame(minWidth: 460, maxWidth: .infinity)
            utilityRail
                .frame(width: 240)
        }
    }

    private var noteRail: some View {
        CommandPanel("Notes", icon: "note.text") {
            VStack(alignment: .leading, spacing: 12) {
                PremiumSearchField(placeholder: "Search notes", text: Binding(
                    get: { scratchpad.query },
                    set: { scratchpad.query = $0 }
                ))
                if scratchpad.filteredNotes.isEmpty {
                    CommandEmptyState(
                        icon: "note.text",
                        title: "No notes found",
                        detail: scratchpad.query.isEmpty ? "Create your first local note." : "Try a different search."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(scratchpad.filteredNotes) { note in
                                ScratchpadNoteRow(
                                    note: note,
                                    isSelected: scratchpad.selectedID == note.id,
                                    onSelect: { scratchpad.select(note.id) }
                                )
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var editor: some View {
        if scratchpad.selected == nil {
            CommandPanel {
                CommandEmptyState(
                    icon: "square.and.pencil",
                    title: "Select or create a note",
                    detail: "Scratchpad keeps dictated thoughts local, searchable, and ready to reuse."
                )
            }
        } else {
            CommandPanel {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 10) {
                        TextField("Title", text: Binding(
                            get: { scratchpad.draftTitle },
                            set: { scratchpad.updateDraftTitle($0) }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        Spacer(minLength: 8)
                        PremiumStatusBadge(icon: "checkmark.circle.fill", text: "Auto-saved", tint: Theme.sage)
                    }

                    TextField("Tags, comma separated", text: Binding(
                        get: { scratchpad.draftTags },
                        set: { scratchpad.updateDraftTags($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 520)

                    noteStats

                    TextEditor(text: Binding(
                        get: { scratchpad.draftBody },
                        set: { scratchpad.updateDraftBody($0) }
                    ))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink)
                    .padding(10)
                    .background(Theme.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Theme.line, lineWidth: 1)
                    )
                    .frame(minHeight: 420, maxHeight: .infinity)

                    if !scratchpad.saveError.isEmpty {
                        Text(scratchpad.saveError)
                            .font(.caption)
                            .foregroundStyle(Theme.red)
                    }
                }
            }
        }
    }

    private var utilityRail: some View {
        CommandPanel("Actions", icon: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 10) {
                if let selected = scratchpad.selected {
                    utilityButton(
                        selected.isPinned ? "Unpin note" : "Pin note",
                        icon: selected.isPinned ? "pin.slash" : "pin"
                    ) {
                        scratchpad.setPinned(!selected.isPinned)
                    }
                }
                utilityButton("Append latest dictation", icon: "text.badge.plus") {
                    if let latest = viewModel.recent.first?.text {
                        scratchpad.appendTextToSelectedOrCreate(latest)
                    }
                }
                .disabled(viewModel.recent.isEmpty)
                utilityButton("Duplicate note", icon: "plus.square.on.square") {
                    scratchpad.duplicateSelected()
                }
                .disabled(scratchpad.selected == nil)
                utilityButton("Copy note Markdown", icon: "doc.on.clipboard") {
                    copyMarkdown()
                }
                .disabled(scratchpad.selected == nil)
                Divider()
                utilityButton("Copy all Markdown", icon: "square.and.arrow.up") {
                    copyAllMarkdown()
                }
                .disabled(scratchpad.notes.isEmpty)
                utilityButton("Copy JSON backup", icon: "externaldrive") {
                    copyAllJSON()
                }
                .disabled(scratchpad.notes.isEmpty)
                utilityButton("Import JSON backup", icon: "square.and.arrow.down") {
                    beginImport()
                }
                Divider()
                utilityButton("Delete note", icon: "trash", tint: Theme.red) {
                    scratchpad.deleteSelected()
                }
                .disabled(scratchpad.selected == nil)
            }
        }
    }

    private func utilityButton(_ title: String,
                               icon: String,
                               tint: Color = Theme.navy,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var noteStats: some View {
        HStack(spacing: 8) {
            PremiumStatusBadge(icon: "textformat", text: wordCountText(draftWordCount), tint: Theme.navy)
            PremiumStatusBadge(icon: "character.cursor.ibeam", text: "\(scratchpad.draftBody.count) chars", tint: Theme.sage)
            if let selected = scratchpad.selected {
                PremiumStatusBadge(icon: "calendar", text: "Updated \(PageFormat.relativeTime(selected.updatedAt))", tint: Theme.gold)
            }
            if let opened = scratchpad.selected?.lastOpenedAt {
                PremiumStatusBadge(icon: "clock", text: "Opened \(PageFormat.relativeTime(opened))", tint: Theme.navy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var importSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            CommandPageHeader(
                eyebrow: "Scratchpad",
                title: "Import JSON",
                subtitle: "Paste a local Scratchpad backup. Matching note IDs are updated; new notes are added."
            )

            TextEditor(text: $importText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .padding(8)
                .background(Theme.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Theme.line, lineWidth: 1)
                )
                .frame(minHeight: 240)

            if !importError.isEmpty {
                Text(importError)
                    .font(.caption)
                    .foregroundStyle(Theme.red)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    showImport = false
                }
                Button("Import") {
                    importScratchpad()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.navy)
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(Theme.cream)
    }

    private func copyMarkdown() {
        guard let markdown = scratchpad.exportMarkdownForSelected() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
    }

    private func copyAllMarkdown() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(scratchpad.exportAllMarkdown(), forType: .string)
    }

    private func copyAllJSON() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(scratchpad.exportAllJSON(), forType: .string)
    }

    private func beginImport() {
        importText = ""
        importError = ""
        showImport = true
    }

    private func importScratchpad() {
        guard scratchpad.importJSON(importText) != nil else {
            importError = "Paste a valid Scratchpad JSON backup."
            return
        }
        importError = ""
        showImport = false
    }

    private var draftWordCount: Int {
        ScratchpadNote.wordCount(in: scratchpad.draftBody)
    }

    private func wordCountText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "word" : "words")"
    }
}
