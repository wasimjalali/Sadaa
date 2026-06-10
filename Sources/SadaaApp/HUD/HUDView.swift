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
        HStack(spacing: 8) {
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        // The pill is the logo's own colorway: navy surface, gold mark. A thin
        // gold hairline ties it to the icon without a decorative border.
        .background(Theme.navy.opacity(0.97), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.12)))
        .fixedSize()
    }

    @ViewBuilder private var content: some View {
        switch display {
        case .recording(_, let level):
            // The whole pill is the living logo while you speak: no timer, no
            // shrunk app icon. The mark itself tells you Sadaa is listening.
            SadaaWaveBars(style: .live(level: level))
        case .transcribing:
            status("Transcribing")
        case .delivering:
            status("Inserting")
        case .optimizing(let target):
            // Plain language for the AI step, no magic-wand iconography.
            status("Optimizing for \(target)")
        case .error(let message):
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.gold)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.cream)
                    .lineLimit(2)
            }
        }
    }

    /// A working state: gold spinner plus a quiet label. The recording state
    /// just showed the full logo, so these brief states stay minimal.
    private func status(_ label: String) -> some View {
        HStack(spacing: 7) {
            ProgressView().controlSize(.mini).tint(Theme.gold)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.cream)
        }
    }
}

/// The Sadaa mark, rendered live: five rounded bars in the logo's
/// 0.4 / 0.7 / 1.0 / 0.7 / 0.4 mountain. In `.live` mode the bars rise with the
/// mic level while always holding the mountain silhouette, so the pill reads as
/// the logo even in silence. `.still` is the resting mark used as a small glyph.
struct SadaaWaveBars: View {
    enum Style: Equatable { case live(level: Float), still }
    let style: Style
    var barHeight: CGFloat = 24
    var barWidth: CGFloat = 4
    var spacing: CGFloat = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The logo's silhouette.
    private let weights: [CGFloat] = [0.4, 0.7, 1.0, 0.7, 0.4]
    /// Shortest a bar ever gets, so the mark never collapses to a flat line.
    private let floorRatio: CGFloat = 0.18
    /// Height held at silence, as a fraction of each bar's full height: keeps the
    /// mountain readable with no sound.
    private let restRatio: CGFloat = 0.6
    /// Mic-level sensitivity. The recorder's level is roughly 0...1 already; this
    /// opens up the usable speaking range.
    private let gain: CGFloat = 11

    /// The logo's goldFront fill (top highlight to deep edge). Functional, not
    /// decoration: these bars are a live level meter wearing the brand mark.
    private var gold: LinearGradient {
        LinearGradient(colors: [Theme.rgb(0xF4, 0xDF, 0xA8), Theme.gold,
                                Theme.rgb(0xB0, 0x83, 0x2A)],
                       startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(weights.indices, id: \.self) { index in
                Capsule()
                    .fill(gold)
                    .frame(width: barWidth, height: height(at: index))
            }
        }
        .frame(height: barHeight, alignment: .center)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: levelKey)
    }

    /// Drives the level animation; constant for `.still` so it never animates.
    private var levelKey: Float {
        if case .live(let level) = style { return level }
        return -1
    }

    private func height(at index: Int) -> CGFloat {
        let floor = barHeight * floorRatio
        let span = barHeight - floor
        let fraction: CGFloat
        switch style {
        case .still:
            fraction = weights[index] * restRatio
        case .live(let level):
            let norm = min(max(CGFloat(level) * gain, 0), 1)
            // Scale from the resting mountain (silence) up to full height (loud).
            let scale = restRatio + (1 - restRatio) * norm
            fraction = weights[index] * scale
        }
        return floor + span * min(max(fraction, 0), 1)
    }
}
