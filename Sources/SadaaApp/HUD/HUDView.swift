import AppKit
import SwiftUI
import SadaaCore

/// Display-only state for the HUD pill. Richer than DictationState on purpose
/// (recording carries seconds and level, optimizing exists only here), so new
/// cases land here, not in the controller state machines.
enum HUDDisplay: Equatable {
    case recording(seconds: Int, level: Float)
    case transcribing
    case delivering
    case optimizing(target: String)
    case error(String)
}

struct HUDView: View {
    let display: HUDDisplay

    var body: some View {
        HStack(spacing: 7) {
            // The app icon gives the pill its identity at a glance. The icns
            // ships in the bundle's Resources; unbundled dev runs just show
            // the generic icon, which is fine.
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 16, height: 16)
            switch display {
            case .recording(let seconds, let level):
                LevelBars(level: level)
                Text(timeString(seconds))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.cream)
            case .transcribing:
                ProgressView().controlSize(.mini).tint(Theme.gold)
                Text("Transcribing")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.cream)
            case .delivering:
                ProgressView().controlSize(.mini).tint(Theme.gold)
                Text("Inserting")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.cream)
            case .optimizing(let target):
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.gold)
                Text("Optimizing for \(target)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.cream)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.gold)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.cream)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Theme.navy.opacity(0.96), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
        .fixedSize()
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
        HStack(spacing: 2) {
            ForEach(weights.indices, id: \.self) { index in
                Capsule()
                    .fill(Theme.gold)
                    .frame(width: 3,
                           height: 4 + 13 * weights[index]
                                   * CGFloat(min(max(level * 12, 0.15), 1)))
            }
        }
        .frame(height: 18)
        .animation(.easeOut(duration: 0.1), value: level)
    }
}
