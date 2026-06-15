import AppKit
import SwiftUI
import SadaaCore

/// Display-only state for the HUD pill. Richer than DictationState on purpose
/// (recording carries seconds and level), so new display-only cases land here,
/// not in the controller state machines.
enum HUDDisplay: Equatable {
    case recording(seconds: Int, level: Float)
    case transcribing
    case delivering
    case error(String)
    /// A brief confirmation that the dictation language was switched.
    case language(LanguagePin)
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
        case .language(let pin):
            // A clear, glanceable confirmation of the language you just switched
            // to: a gold globe and the language name, larger than the working
            // labels so it reads at a glance from across the screen.
            HStack(spacing: 7) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                Text(PageFormat.languageLabel(pin))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.cream)
            }
        }
    }

    /// A working state: a spinner plus a quiet label. The recording state just
    /// showed the full logo, so these brief states stay minimal. The spinner is
    /// cream, not gold: dark gold on the near-black navy pill was effectively
    /// invisible, so the ring never read as "working". Cream matches the label
    /// beside it, which was always legible.
    private func status(_ label: String) -> some View {
        HStack(spacing: 7) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .tint(Theme.cream)
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
        switch style {
        case .still:
            bars { fraction(at: $0, level: 0, phase: 0, animated: false) }
        case .live(let level):
            if reduceMotion {
                // Reduced motion: follow loudness only, no ripple, gentle ease.
                bars { fraction(at: $0, level: level, phase: 0, animated: false) }
                    .animation(.easeOut(duration: 0.12), value: level)
            } else {
                // A continuous time source so the bars ripple EVERY frame, not
                // only when a new level sample arrives (~10-30Hz). The mic level
                // sets the wave's amplitude; time gives it the flow. This is what
                // makes the mark read as a live waveform instead of a slow pulse.
                TimelineView(.animation) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    bars { fraction(at: $0, level: level, phase: phase, animated: true) }
                }
            }
        }
    }

    private func bars(_ heightFraction: @escaping (Int) -> CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(weights.indices, id: \.self) { index in
                Capsule()
                    .fill(gold)
                    .frame(width: barWidth, height: pixels(heightFraction(index)))
            }
        }
        .frame(height: barHeight, alignment: .center)
    }

    /// Maps a 0...1 fraction of full height to pixels, never below the floor so
    /// the mark never collapses to a flat line.
    private func pixels(_ fraction: CGFloat) -> CGFloat {
        let floor = barHeight * floorRatio
        let span = barHeight - floor
        return floor + span * min(max(fraction, 0), 1)
    }

    /// Height fraction (0...1) for one bar. The bar sits on the logo's resting
    /// mountain, rises with loudness, and ripples with a per-bar phase offset so
    /// the five bars travel as a wave instead of pulsing in lockstep. The ripple
    /// is barely there in silence and grows with the mic level; the wave also
    /// speeds up as you get louder, for an energetic, realistic feel.
    private func fraction(at index: Int, level: Float,
                          phase: Double, animated: Bool) -> CGFloat {
        let norm = min(max(CGFloat(level) * gain, 0), 1)
        let base = weights[index] * (restRatio + (1 - restRatio) * norm)
        guard animated else { return base }
        let speed = 7.0 + 7.0 * Double(norm)          // quiet = calm, loud = lively
        let offset = Double(index) * 0.9              // staggers the bars into a wave
        let ripple = sin(phase * speed + offset)      // -1...1
        let amplitude = 0.05 + 0.25 * norm            // gentle idle, strong on sound
        return base + CGFloat(ripple) * amplitude * weights[index]
    }
}
