import SwiftUI
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
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.charcoal)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(PageFormat.relativeTime(note.createdAt))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.charcoal.opacity(0.5))
                            }
                            Button {
                                viewModel.removeNote(note.id)
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
                .frame(maxWidth: 640, alignment: .leading)
            }
        }
    }
}
