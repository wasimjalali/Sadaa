import SwiftUI
import SadaaCore

enum HUDDisplay: Equatable {
    case recording(seconds: Int, level: Float)
    case transcribing
    case delivering
    case error(String)
}

struct HUDView: View {
    let display: HUDDisplay

    var body: some View {
        HStack(spacing: 10) {
            switch display {
            case .recording(let seconds, let level):
                LevelBars(level: level)
                Text(timeString(seconds))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Theme.cream)
                Text("Esc to cancel")
                    .font(.caption)
                    .foregroundStyle(Theme.cream.opacity(0.55))
            case .transcribing:
                ProgressView().controlSize(.small).tint(Theme.gold)
                Text("Transcribing…").foregroundStyle(Theme.cream)
            case .delivering:
                ProgressView().controlSize(.small).tint(Theme.gold)
                Text("Inserting…").foregroundStyle(Theme.cream)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.gold)
                Text(message)
                    .foregroundStyle(Theme.cream)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(minWidth: 220, maxWidth: 380)
        .background(Theme.navy.opacity(0.96), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Five gold bars that scale with the mic level, Sadaa logo style.
private struct LevelBars: View {
    let level: Float
    private let weights: [CGFloat] = [0.4, 0.7, 1.0, 0.7, 0.4]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(weights.indices, id: \.self) { index in
                Capsule()
                    .fill(Theme.gold)
                    .frame(width: 4,
                           height: 6 + 22 * weights[index]
                                   * CGFloat(min(max(level * 12, 0.15), 1)))
            }
        }
        .animation(.easeOut(duration: 0.1), value: level)
    }
}
