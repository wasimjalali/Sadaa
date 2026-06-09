import SwiftUI
import AppKit
import SadaaCore

/// Large circular mic control for the main window. Renders every dictation
/// state with subtle motion and forwards taps to `onTap`. The state caption
/// lives on the page so it can transition independently. Karko palette only.
struct MicButton: View {
    let state: DictationState
    let onTap: () -> Void

    private let diameter: CGFloat = 96

    @State private var pressed = false
    @State private var hovering = false

    var body: some View {
        ZStack {
            ring
            disc
            glyph
        }
        .frame(width: diameter + 28, height: diameter + 28)
        .contentShape(Circle())
        .scaleEffect(pressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: pressed)
        .onTapGesture { onTap() }
        // A zero-distance drag gives us press-down / press-up feedback without
        // swallowing the tap above.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !pressed { pressed = true } }
                .onEnded { _ in pressed = false }
        )
        .onHover { inside in
            hovering = inside
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .accessibilityLabel("Dictation control")
    }

    // MARK: - Ring (recording pulse)

    @ViewBuilder
    private var ring: some View {
        if state == .recording {
            PulsingRing(diameter: diameter)
        }
    }

    // MARK: - Disc

    @ViewBuilder
    private var disc: some View {
        switch state {
        case .recording:
            Circle()
                .fill(Theme.gold)
                .frame(width: diameter, height: diameter)
        case .transcribing, .delivering:
            ZStack {
                Circle()
                    .fill(Theme.gold.opacity(0.22))
                ShimmerArc(diameter: diameter)
            }
            .frame(width: diameter, height: diameter)
        case .idle, .error:
            Circle()
                .fill(Theme.gold)
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(hovering ? 0.10 : 0.0))
                )
                .shadow(
                    color: Theme.gold.opacity(hovering ? 0.35 : 0.0),
                    radius: hovering ? 12 : 0
                )
                .frame(width: diameter, height: diameter)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hovering)
        }
    }

    // MARK: - Glyph

    @ViewBuilder
    private var glyph: some View {
        switch state {
        case .recording:
            StopGlyph()
        case .transcribing, .delivering:
            ProgressView()
                .controlSize(.regular)
                .tint(Theme.gold)
        case .idle, .error:
            BreathingMic()
        }
    }
}

/// Stop glyph for the recording state. Bounces once on entry so the switch to
/// recording reads as a deliberate beat.
private struct StopGlyph: View {
    @State private var bounce = false

    var body: some View {
        Image(systemName: "stop.fill")
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(.white)
            .symbolEffect(.bounce, value: bounce)
            .onAppear { bounce.toggle() }
    }
}

/// Idle/error mic glyph with a slow, gentle breathe so the control never feels
/// fully dead while still reading as calm.
private struct BreathingMic: View {
    @State private var breathe = false

    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 34, weight: .medium))
            .foregroundStyle(.white)
            .scaleEffect(breathe ? 1.04 : 0.98)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
    }
}

/// A gold ring that pulses outward to signal active recording. Two staggered
/// rings give the expand-and-fade a continuous feel.
private struct PulsingRing: View {
    let diameter: CGFloat
    @State private var animating = false

    var body: some View {
        ZStack {
            wave(delay: 0)
            wave(delay: 0.55)
        }
        .onAppear { animating = true }
    }

    private func wave(delay: Double) -> some View {
        Circle()
            .strokeBorder(Theme.gold, lineWidth: 4)
            .frame(width: diameter, height: diameter)
            .scaleEffect(animating ? 1.32 : 1.0)
            .opacity(animating ? 0.0 : 0.55)
            .animation(
                .easeOut(duration: 1.1)
                    .repeatForever(autoreverses: false)
                    .delay(delay),
                value: animating
            )
    }
}

/// A faint rotating gold arc layered on the transcribing/inserting disc so the
/// processing state shimmers gently instead of sitting static.
private struct ShimmerArc: View {
    let diameter: CGFloat
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.32)
            .stroke(
                Theme.gold.opacity(0.85),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .frame(width: diameter - 8, height: diameter - 8)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    spin = true
                }
            }
    }
}
