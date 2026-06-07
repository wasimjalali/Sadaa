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

    private static let navy = Color(red: 0x1E / 255, green: 0x3A / 255, blue: 0x5F / 255)
    private static let gold = Color(red: 0xD4 / 255, green: 0xA8 / 255, blue: 0x53 / 255)
    private static let cream = Color(red: 0xFA / 255, green: 0xF7 / 255, blue: 0xF2 / 255)

    var body: some View {
        HStack(spacing: 10) {
            switch display {
            case .recording(let seconds, let level):
                LevelBars(level: level)
                Text(timeString(seconds))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Self.cream)
                Text("Esc to cancel")
                    .font(.caption)
                    .foregroundStyle(Self.cream.opacity(0.55))
            case .transcribing:
                ProgressView().controlSize(.small).tint(Self.gold)
                Text("Transcribing…").foregroundStyle(Self.cream)
            case .delivering:
                ProgressView().controlSize(.small).tint(Self.gold)
                Text("Inserting…").foregroundStyle(Self.cream)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Self.gold)
                Text(message)
                    .foregroundStyle(Self.cream)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(minWidth: 220, maxWidth: 380)
        .background(Self.navy.opacity(0.96), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Five gold bars that scale with the mic level, Sadaa logo style.
private struct LevelBars: View {
    let level: Float
    private static let gold = Color(red: 0xD4 / 255, green: 0xA8 / 255, blue: 0x53 / 255)
    private let weights: [CGFloat] = [0.4, 0.7, 1.0, 0.7, 0.4]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(weights.indices, id: \.self) { index in
                Capsule()
                    .fill(Self.gold)
                    .frame(width: 4,
                           height: 6 + 22 * weights[index]
                                   * CGFloat(min(max(level * 12, 0.15), 1)))
            }
        }
        .animation(.easeOut(duration: 0.1), value: level)
    }
}
