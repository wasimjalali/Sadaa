import SwiftUI
import SadaaCore

/// Large circular mic control for the main window. Renders every dictation
/// state and forwards taps to `onTap`. Self-contained, Karko palette only.
struct MicButton: View {
    let state: DictationState
    let onTap: () -> Void

    private let diameter: CGFloat = 140

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                circle
                glyph
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .onTapGesture { onTap() }

            caption
        }
    }

    // MARK: - Circle

    @ViewBuilder
    private var circle: some View {
        switch state {
        case .recording:
            PulsingRing(diameter: diameter)
            Circle().fill(Theme.gold)
        case .transcribing, .delivering:
            Circle().fill(Theme.gold.opacity(0.28))
        case .idle, .error:
            Circle().fill(Theme.gold)
        }
    }

    // MARK: - Glyph

    @ViewBuilder
    private var glyph: some View {
        switch state {
        case .recording:
            Image(systemName: "stop.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.white)
        case .transcribing, .delivering:
            ProgressView()
                .controlSize(.large)
                .tint(Theme.gold)
        case .idle, .error:
            Image(systemName: "mic.fill")
                .font(.system(size: 50, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Caption

    @ViewBuilder
    private var caption: some View {
        switch state {
        case .recording:
            Text("Recording. Esc to cancel")
                .font(.caption)
                .foregroundStyle(Color.red.opacity(0.85))
        case .transcribing:
            Text("Transcribing")
                .font(.caption)
                .foregroundStyle(Theme.charcoal.opacity(0.7))
        case .delivering:
            Text("Inserting")
                .font(.caption)
                .foregroundStyle(Theme.charcoal.opacity(0.7))
        case .idle, .error:
            Text("Tap or press Right Option")
                .font(.caption)
                .foregroundStyle(Theme.charcoal.opacity(0.7))
        }
    }
}

/// A gold ring that pulses outward to signal active recording.
private struct PulsingRing: View {
    let diameter: CGFloat
    @State private var animating = false

    var body: some View {
        Circle()
            .strokeBorder(Theme.gold, lineWidth: 4)
            .scaleEffect(animating ? 1.25 : 1.0)
            .opacity(animating ? 0.0 : 0.6)
            .frame(width: diameter, height: diameter)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                    animating = true
                }
            }
    }
}
