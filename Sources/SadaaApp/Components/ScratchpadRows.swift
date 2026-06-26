import SwiftUI
import SadaaCore

struct ScratchpadNoteRow: View {
    let note: ScratchpadNote
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                    }
                    Text(note.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.navy : Theme.charcoal)
                        .lineLimit(1)
                }
                Text(note.body.isEmpty ? "Empty note" : note.body)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.charcoal.opacity(0.58))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(PageFormat.relativeTime(note.updatedAt))
                    Text(wordCountText(note.wordCount))
                    if !note.tags.isEmpty {
                        Text(note.tags.map { "#\($0)" }.joined(separator: " "))
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.sage)
                .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.gold.opacity(0.16) : Theme.creamSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Theme.gold.opacity(0.48) : Theme.gold.opacity(0.16),
                                  lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func wordCountText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "word" : "words")"
    }
}
