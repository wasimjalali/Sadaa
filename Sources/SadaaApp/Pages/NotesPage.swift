import SwiftUI
import AppKit
import SadaaCore

/// Lightweight dictated notes. Focus the field and use the dictation hotkey to
/// speak a note, or type it, then Add. Spec section 4 (NotesStore).
struct NotesPage: View {
    @ObservedObject var viewModel: SadaaViewModel

    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notes")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.charcoal)

            composer
            list
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $draft)
                .frame(minHeight: 80)
                .font(.system(size: 13))
                .padding(8)
                .background(Theme.creamSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Theme.gold.opacity(0.2), lineWidth: 1)
                )
            HStack {
                Text("Tip: focus this box and press Right Option to dictate.")
                    .font(.caption)
                    .foregroundStyle(Theme.charcoal.opacity(0.55))
                Spacer()
                Button("Add note") { add() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.navy)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
    }

    private func add() {
        viewModel.addNote(draft)
        draft = ""
    }

    @ViewBuilder
    private var list: some View {
        if viewModel.notes.isEmpty {
            Text("No notes yet.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.charcoal.opacity(0.5))
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.notes) { note in
                        NoteRow(
                            note: note,
                            onCommit: { viewModel.updateNote(note.id, text: $0) },
                            onDelete: { viewModel.removeNote(note.id) })
                    }
                }
                .frame(maxWidth: 640, alignment: .leading)
            }
        }
    }
}

/// One note row: selectable text with Copy, Edit and Delete, swapping to an
/// inline editor while editing. Copy uses the same NSPasteboard helper as the
/// Home and History rows; editing keeps the note's timestamp and position.
private struct NoteRow: View {
    let note: Note
    let onCommit: (String) -> Void
    let onDelete: () -> Void

    @State private var editing = false
    @State private var draft = ""
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if editing {
                    TextEditor(text: $draft)
                        .frame(minHeight: 60)
                        .font(.system(size: 13))
                        .padding(6)
                        .background(Theme.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    Text(note.text)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.charcoal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                Text(PageFormat.relativeTime(note.createdAt))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.charcoal.opacity(0.5))
            }
            actions
        }
        .padding(12)
        .background(Theme.creamSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var actions: some View {
        if editing {
            HStack(spacing: 10) {
                Button { commit() } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.sage)
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button { editing = false } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Theme.charcoal.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        } else {
            HStack(spacing: 10) {
                Button { copy() } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copied ? Theme.sage : Theme.charcoal.opacity(0.6))
                        .symbolEffect(.bounce, value: copied)
                }
                .buttonStyle(.plain)
                Button {
                    draft = note.text
                    editing = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(Theme.charcoal.opacity(0.6))
                }
                .buttonStyle(.plain)
                Button { onDelete() } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Theme.charcoal.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func commit() {
        onCommit(draft)
        editing = false
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.text, forType: .string)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { copied = false }
        }
    }
}
