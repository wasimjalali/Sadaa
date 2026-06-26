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
        HStack(spacing: 0) {
            noteList
            Divider()
            editor
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showImport) {
            importSheet
        }
    }

    private var noteList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Scratchpad")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.charcoal)
                Spacer()
                Button {
                    _ = scratchpad.createNote(title: "Untitled", body: " ")
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(PremiumIconButtonStyle())
                .help("New note")
                Menu {
                    Button("Copy all Markdown") { copyAllMarkdown() }
                        .disabled(scratchpad.notes.isEmpty)
                    Button("Copy JSON backup") { copyAllJSON() }
                        .disabled(scratchpad.notes.isEmpty)
                    Divider()
                    Button("Import JSON backup") { beginImport() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(PremiumIconButtonStyle())
                .help("Export or import Scratchpad")
            }
            PremiumSearchField(placeholder: "Search notes", text: Binding(
                get: { scratchpad.query },
                set: { scratchpad.query = $0 }
            ))
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
                .padding(.bottom, 16)
            }
        }
        .padding(20)
        .frame(minWidth: 290, maxWidth: 290, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.cream)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 14) {
            if scratchpad.selected == nil {
                emptyEditor
            } else {
                editorToolbar
                TextField("Title", text: Binding(
                    get: { scratchpad.draftTitle },
                    set: { scratchpad.updateDraftTitle($0) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.charcoal)

                TextField("Tags, comma separated", text: Binding(
                    get: { scratchpad.draftTags },
                    set: { scratchpad.updateDraftTags($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 420)

                noteStats

                TextEditor(text: Binding(
                    get: { scratchpad.draftBody },
                    set: { scratchpad.updateDraftBody($0) }
                ))
                .font(.system(size: 14))
                .foregroundStyle(Theme.charcoal)
                .padding(8)
                .background(Theme.creamSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1)
                )
                .frame(maxWidth: 760, maxHeight: .infinity)

                if !scratchpad.saveError.isEmpty {
                    Text(scratchpad.saveError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.cream)
    }

    private var editorToolbar: some View {
        HStack(spacing: 8) {
            if let selected = scratchpad.selected {
                Button {
                    scratchpad.setPinned(!selected.isPinned)
                } label: {
                    Image(systemName: selected.isPinned ? "pin.slash" : "pin")
                }
                .buttonStyle(PremiumIconButtonStyle())
                .help(selected.isPinned ? "Unpin note" : "Pin note")
            }
            Button {
                scratchpad.duplicateSelected()
            } label: {
                Image(systemName: "plus.square.on.square")
            }
            .buttonStyle(PremiumIconButtonStyle())
            .help("Duplicate note")
            Button {
                if let latest = viewModel.recent.first?.text {
                    scratchpad.appendTextToSelectedOrCreate(latest)
                }
            } label: {
                Image(systemName: "text.badge.plus")
            }
            .buttonStyle(PremiumIconButtonStyle())
            .help("Append latest dictation")
            Button {
                copyMarkdown()
            } label: {
                Image(systemName: "doc.on.clipboard")
            }
            .buttonStyle(PremiumIconButtonStyle())
            .help("Copy markdown")
            Button {
                scratchpad.deleteSelected()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(PremiumIconButtonStyle())
            .help("Delete note")
            Spacer()
            PremiumStatusBadge(icon: "checkmark.circle.fill", text: "Auto-saved", tint: Theme.sage)
        }
        .frame(maxWidth: 760)
    }

    private var noteStats: some View {
        HStack(spacing: 8) {
            PremiumStatusBadge(icon: "textformat", text: wordCountText(draftWordCount), tint: Theme.navy)
            PremiumStatusBadge(icon: "character.cursor.ibeam", text: "\(scratchpad.draftBody.count) chars", tint: Theme.sage)
            if let opened = scratchpad.selected?.lastOpenedAt {
                PremiumStatusBadge(icon: "clock", text: "Opened \(PageFormat.relativeTime(opened))", tint: Theme.gold)
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var emptyEditor: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.gold300)
            Button {
                _ = scratchpad.createNote(title: "Untitled", body: " ")
            } label: {
                Label("New note", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.navy)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var importSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Import Scratchpad JSON")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.charcoal)
            Text("Paste a Scratchpad JSON backup. Matching note IDs are updated; new notes are added.")
                .font(.subheadline)
                .foregroundStyle(Theme.charcoal.opacity(0.68))

            TextEditor(text: $importText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.charcoal)
                .padding(8)
                .background(Theme.creamSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1)
                )
                .frame(minHeight: 220)

            if !importError.isEmpty {
                Text(importError)
                    .font(.caption)
                    .foregroundStyle(.red)
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
        .frame(width: 520)
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
