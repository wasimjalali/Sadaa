import SwiftUI
import AppKit
import SadaaCore

/// Shared formatters and label helpers for the windowed pages.
enum PageFormat {
    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    static func relativeTime(_ date: Date) -> String {
        relative.localizedString(for: date, relativeTo: Date())
    }

    static func languageLabel(_ pin: LanguagePin) -> String {
        switch pin {
        case .auto: return "Auto"
        case .en: return "English"
        case .de: return "German"
        }
    }

    static func minutes(_ value: Double) -> String {
        String(format: "%.1f min", value)
    }

    static func dollars(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}

/// The landing page: the mic control, today's activity, connection and language
/// status, and a short list of the most recent dictations.
struct HomePage: View {
    @ObservedObject var viewModel: SadaaViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 4)

                MicButton(state: viewModel.dictationState) { viewModel.toggle() }

                stateLine

                if viewModel.canRetry {
                    retryButton
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                todayStrip

                statusChips

                recentSection

                Spacer(minLength: 4)
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .top)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.canRetry)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - State line

    private var stateLine: some View {
        Text(stateText)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(stateColor)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 360)
            .contentTransition(.opacity)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: stateText)
            .id(stateText)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var stateText: String {
        switch viewModel.dictationState {
        case .idle: return "Tap your hotkey or click to dictate"
        case .recording: return "Listening..."
        case .transcribing: return "Transcribing..."
        case .delivering: return "Inserting..."
        case .error(let message): return message
        }
    }

    private var stateColor: Color {
        switch viewModel.dictationState {
        case .recording: return Theme.sage
        case .error: return Color.red.opacity(0.85)
        default: return Theme.charcoal.opacity(0.7)
        }
    }

    // MARK: - Retry

    private var retryButton: some View {
        Button {
            viewModel.retry()
        } label: {
            Label("Retry last dictation", systemImage: "arrow.clockwise")
                .font(.system(size: 13, weight: .medium))
        }
        .buttonStyle(HomePressableButtonStyle())
        .tint(Theme.navy)
    }

    // MARK: - Today strip

    /// Records created since midnight today. Gated on `recent.count` so a new
    /// dictation re-renders these chips.
    private var todayRecords: [DictationRecord] {
        _ = viewModel.recent.count
        let start = Calendar.current.startOfDay(for: Date())
        return viewModel.historyStore.all().filter { $0.createdAt >= start }
    }

    private var todayCount: Int { todayRecords.count }

    private var todayMinutes: Double {
        todayRecords.reduce(0) { $0 + ($1.durationSeconds ?? 0) } / 60
    }

    private var todayWords: Int {
        todayRecords.reduce(0) { sum, record in
            sum + record.text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        }
    }

    private var todayStrip: some View {
        HStack(spacing: 12) {
            StatChip(icon: "waveform", value: "\(todayCount)", label: todayCount == 1 ? "dictation" : "dictations")
            StatChip(icon: "clock", value: String(format: "%.1f", todayMinutes), label: "minutes")
            StatChip(icon: "textformat", value: "\(todayWords)", label: "words")
        }
        .frame(maxWidth: 520)
    }

    // MARK: - Status chips

    private var statusChips: some View {
        HStack(spacing: 10) {
            StatusCapsule(
                dotColor: viewModel.azureConfigured ? Theme.sage : Theme.gold,
                text: viewModel.azureConfigured ? "Azure connected" : "Not configured. Open Settings."
            )
            StatusCapsule(
                icon: "globe",
                text: PageFormat.languageLabel(viewModel.languagePin)
            )
        }
        .frame(maxWidth: 520)
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.charcoal.opacity(0.7))

            if viewModel.recent.isEmpty {
                emptyRecent
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recent.prefix(5)) { record in
                        RecentRow(record: record)
                    }
                }
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private var emptyRecent: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .font(.system(size: 30))
                .foregroundStyle(Theme.gold300)
            Text("Your dictations will show up here.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.charcoal.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

// MARK: - Stat chip

/// A small page-local activity chip with an icon and a number that animates on
/// change.
private struct StatChip: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.charcoal)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.charcoal.opacity(0.55))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.creamSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Status capsule

/// A compact status pill. Shows either a colored status dot or a leading icon.
private struct StatusCapsule: View {
    var dotColor: Color?
    var icon: String?
    let text: String

    init(dotColor: Color? = nil, icon: String? = nil, text: String) {
        self.dotColor = dotColor
        self.icon = icon
        self.text = text
    }

    var body: some View {
        HStack(spacing: 7) {
            if let dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.charcoal.opacity(0.55))
            }
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.charcoal.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Theme.creamSurface)
        )
        .overlay(
            Capsule()
                .strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Recent row

/// A single recent-dictation row with hover highlight, a leading gold accent
/// bar on hover and a Copy button that morphs to a sage checkmark.
private struct RecentRow: View {
    let record: DictationRecord

    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.gold)
                .frame(width: 3)
                .opacity(hovering ? 1 : 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.charcoal)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                Text(PageFormat.relativeTime(record.createdAt))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.charcoal.opacity(0.5))
            }

            copyButton
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(hovering ? Theme.cream : Theme.creamSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.gold.opacity(hovering ? 0.32 : 0.18), lineWidth: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hovering)
        .onHover { hovering = $0 }
    }

    private var copyButton: some View {
        Button {
            copy(record.text)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { copied = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .symbolEffect(.bounce, value: copied)
                Text(copied ? "Copied" : "Copy")
                    .font(.system(size: 12, weight: .medium))
                    .contentTransition(.opacity)
            }
            .foregroundStyle(copied ? Theme.sage : Theme.navy)
        }
        .buttonStyle(HomePressableButtonStyle())
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Button style

/// A borderless button style with a pressed-scale and pointing-hand cursor.
private struct HomePressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
    }
}
