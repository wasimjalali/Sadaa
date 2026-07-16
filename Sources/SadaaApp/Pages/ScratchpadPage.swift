import SwiftUI
import AppKit
import SadaaCore

struct ScratchpadPage: View {
    @ObservedObject var viewModel: SadaaViewModel
    @ObservedObject var scratchpad: ScratchpadViewModel

    @State private var showImport = false
    @State private var importText = ""
    @State private var importMessage = ""

    init(viewModel: SadaaViewModel) {
        self.viewModel = viewModel
        self.scratchpad = viewModel.scratchpad
    }

    var body: some View {
        FillRemainingHeightLayout(spacing: 22) {
            header
            workspace
        }
        .padding(32)
        .frame(maxWidth: 1180, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
        .sheet(isPresented: $showImport) { importSheet }
        .onDisappear { scratchpad.commitDraft() }
    }

    private var header: some View {
        CommandPageHeader(
            title: "Notes",
            subtitle: "Keep dictated ideas, reusable text and working notes in one private place."
        ) {
            Button("New note") { scratchpad.createNote() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brand)
                .controlSize(.large)
                .clickableCursor()
        }
    }

    private var workspace: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 18) {
                noteList
                    .frame(minWidth: 240, idealWidth: 300, maxWidth: 320)
                    .frame(height: geometry.size.height)
                editor
                    .frame(minWidth: 300, maxWidth: .infinity)
                    .frame(height: geometry.size.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .layoutPriority(1)
    }

    private var noteList: some View {
        VStack(alignment: .leading, spacing: 12) {
            PremiumSearchField(placeholder: "Search notes", text: $scratchpad.query)

            if scratchpad.filteredNotes.isEmpty {
                CommandEmptyState(
                    icon: scratchpad.notes.isEmpty ? "note.text" : "magnifyingglass",
                    title: scratchpad.notes.isEmpty ? "No notes yet" : "No matching notes",
                    detail: scratchpad.notes.isEmpty
                        ? "Create a note or send a transcript here from the Library."
                        : "Try a shorter search or a tag."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(scratchpad.filteredNotes) { note in
                            ScratchpadNoteRow(
                                note: note,
                                isSelected: scratchpad.selectedID == note.id,
                                onSelect: { scratchpad.select(note.id) }
                            )
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.surfaceSubtle, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxHeight: .infinity)
    }

    private var editor: some View {
        Group {
            if let selected = scratchpad.selected {
                VStack(alignment: .leading, spacing: 14) {
                    editorToolbar(selected)

                    TextField(
                        "Note title",
                        text: Binding(
                            get: { scratchpad.draftTitle },
                            set: { scratchpad.updateDraftTitle($0) }
                        )
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.ink)

                    TextEditor(
                        text: Binding(
                            get: { scratchpad.draftBody },
                            set: { scratchpad.updateDraftBody($0) }
                        )
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink)
                    .scrollContentBackground(.hidden)
                    .padding(2)
                    .frame(minHeight: 120, maxHeight: .infinity)
                    .layoutPriority(1)

                    Divider().overlay(Theme.line)

                    HStack(spacing: 12) {
                        TextField(
                            "Tags, comma separated",
                            text: Binding(
                                get: { scratchpad.draftTags },
                                set: { scratchpad.updateDraftTags($0) }
                            )
                        )
                        .premiumInputChrome()

                        Text("\(ScratchpadNote.wordCount(in: scratchpad.draftBody)) words")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(Theme.muted)
                        Text("Saved automatically")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.success)
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    if !scratchpad.saveError.isEmpty {
                        Text(scratchpad.saveError)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.danger)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                CommandEmptyState(
                    icon: "note.text",
                    title: "Select or create a note",
                    detail: "Notes save automatically as you type."
                )
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
    }

    private func editorToolbar(_ selected: ScratchpadNote) -> some View {
        HStack {
            Button {
                scratchpad.setPinned(!selected.isPinned)
            } label: {
                Label(selected.isPinned ? "Unpin" : "Pin", systemImage: selected.isPinned ? "pin.slash" : "pin")
            }
            .buttonStyle(.borderless)
            .clickableCursor()

            Button("Append latest dictation") {
                if let latest = viewModel.recent.first?.text {
                    scratchpad.appendTextToSelectedOrCreate(latest)
                }
            }
            .buttonStyle(.borderless)
            .clickableCursor()
            .disabled(viewModel.recent.isEmpty)

            Spacer()

            Menu {
                Button("Duplicate note") { scratchpad.duplicateSelected() }
                Button("Copy note as Markdown") {
                    if let value = scratchpad.exportMarkdownForSelected() { copy(value) }
                }
                Button("Copy all notes as Markdown") { copy(scratchpad.exportAllMarkdown()) }
                Button("Copy JSON backup") { copy(scratchpad.exportAllJSON()) }
                Button("Import JSON backup") {
                    importText = ""
                    importMessage = ""
                    showImport = true
                }
                Divider()
                Button("Delete note", role: .destructive) { scratchpad.deleteSelected() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 34)
            .help("Note actions")
            .clickableCursor()
        }
        .font(.system(size: 12, weight: .medium))
    }

    private var importSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import notes")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Paste a Sadaa JSON backup. Existing note IDs are updated and new notes are added.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)

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
                Button("Import") {
                    guard let result = scratchpad.importJSON(importText) else {
                        importMessage = "The JSON backup could not be read."
                        return
                    }
                    importMessage = "Imported \(result.inserted) new and updated \(result.updated)."
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brand)
                .clickableCursor()
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 560, height: 430)
        .background(Theme.surface)
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
