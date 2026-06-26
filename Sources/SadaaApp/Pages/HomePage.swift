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

/// Command-center home: readiness, live dictation state, today's usage,
/// recent recovery actions, and Memory learning pulse.
struct HomePage: View {
    @ObservedObject var viewModel: SadaaViewModel

    @State private var correctionRecord: DictationRecord?
    @State private var correctionObserved = ""
    @State private var correctionCorrected = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                readinessStrip
                primaryWorkspace
                recentAndLearning
            }
            .padding(30)
            .frame(maxWidth: 1120, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: viewModel.canRetry)
        }
        .background(Theme.cream)
        .sheet(item: $correctionRecord) { record in
            correctionSheet(record)
        }
    }

    private var header: some View {
        CommandPageHeader(
            eyebrow: "Local AI voice layer",
            title: "Command Center",
            subtitle: "Dictate, recover, and teach Sadaa your AI-specialist vocabulary from one calm cockpit."
        ) {
            HStack(spacing: 8) {
                PremiumStatusBadge(
                    icon: "globe",
                    text: PageFormat.languageLabel(viewModel.languagePin),
                    tint: Theme.navy
                )
                PremiumStatusBadge(
                    icon: viewModel.hotkeyActive ? "keyboard.fill" : "keyboard",
                    text: viewModel.hotkeyActive ? "Hotkeys active" : "Grant access",
                    tint: viewModel.hotkeyActive ? Theme.sage : Theme.gold
                )
            }
        }
    }

    private var readinessStrip: some View {
        CommandPanel {
            HStack(spacing: 10) {
                readinessBadge(
                    icon: viewModel.azureConfigured ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                    title: viewModel.azureConfigured ? "Azure ready" : "Azure setup needed",
                    detail: viewModel.azureConfigured ? "Transcription endpoint configured" : "Add endpoint, deployment, and key",
                    tint: viewModel.azureConfigured ? Theme.sage : Theme.gold
                )
                readinessBadge(
                    icon: "text.book.closed.fill",
                    title: "\(viewModel.languageMemory.terms.count) terms",
                    detail: "\(viewModel.languageMemory.replacements.count) corrections, \(viewModel.languageMemory.snippets.count) snippets",
                    tint: Theme.navy
                )
                readinessBadge(
                    icon: "chart.bar.fill",
                    title: PageFormat.minutes(viewModel.monthlyCost.minutes),
                    detail: "\(PageFormat.dollars(viewModel.monthlyCost.cost)) estimated this month",
                    tint: Theme.gold
                )
            }
        }
    }

    private func readinessBadge(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var primaryWorkspace: some View {
        HStack(alignment: .top, spacing: 18) {
            CommandPanel("Voice", icon: "waveform") {
                VStack(spacing: 16) {
                    MicButton(state: viewModel.dictationState) { viewModel.toggle() }
                        .padding(.top, 6)
                    Text(stateText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(stateTint)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                    if viewModel.canRetry {
                        Button {
                            viewModel.retry()
                        } label: {
                            Label("Retry retained audio", systemImage: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.navy)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 290)
            }
            .frame(maxWidth: 450)

            CommandPanel("Today", icon: "calendar") {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        CommandMetric(icon: "waveform", value: "\(todayCount)", label: todayCount == 1 ? "dictation" : "dictations", tint: Theme.navy)
                        CommandMetric(icon: "clock", value: String(format: "%.1f", todayMinutes), label: "minutes", tint: Theme.gold)
                    }
                    HStack(spacing: 10) {
                        CommandMetric(icon: "textformat", value: "\(todayWords)", label: "words", tint: Theme.sage)
                        CommandMetric(icon: "sparkles", value: "\(todayMemoryEvents)", label: "memory events", tint: Theme.navy)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model posture")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.navy)
                        Text("Fast Azure transcription, local deterministic Memory, optional GPT cleanup.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 290)
            }
        }
    }

    private var recentAndLearning: some View {
        HStack(alignment: .top, spacing: 18) {
            recentPanel
                .frame(maxWidth: .infinity)
            learningPulsePanel
                .frame(width: 330)
        }
    }

    private var recentPanel: some View {
        CommandPanel("Recent dictations", icon: "clock.arrow.circlepath") {
            if viewModel.recent.isEmpty {
                CommandEmptyState(
                    icon: "text.bubble",
                    title: "No dictations yet",
                    detail: "Your newest transcripts will appear here with copy, note, learn, and reprocess actions."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.recent.prefix(5)) { record in
                        RecentCommandRow(
                            record: record,
                            onCopy: { copy(record.text) },
                            onSendToScratchpad: { viewModel.sendToScratchpad(record) },
                            onLearn: { beginCorrection(record) },
                            onReprocess: { viewModel.reprocessHistoryWithLanguageMemory(record) }
                        )
                    }
                }
            }
        }
    }

    private var learningPulsePanel: some View {
        CommandPanel("Learning Pulse", icon: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    CommandMetric(
                        icon: "lightbulb.fill",
                        value: "\(viewModel.languageMemory.suggestions.count)",
                        label: "queued",
                        tint: Theme.gold
                    )
                }
                if viewModel.languageMemory.suggestions.isEmpty {
                    Text("Corrections and new technical terms will surface here as Sadaa learns from formatting, history, and your edits.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.languageMemory.suggestions.prefix(4)) { suggestion in
                            LearningPulseRow(suggestion: suggestion)
                        }
                    }
                }
            }
        }
    }

    private var stateText: String {
        switch viewModel.dictationState {
        case .idle: return "Tap your hotkey or click the mic to dictate."
        case .recording: return "Listening. Press Esc to cancel."
        case .transcribing: return "Transcribing with Azure."
        case .delivering: return "Inserting at your cursor."
        case .error(let message): return message
        }
    }

    private var stateTint: Color {
        switch viewModel.dictationState {
        case .recording: return Theme.sage
        case .transcribing, .delivering: return Theme.gold
        case .error: return Theme.red
        case .idle: return Theme.muted
        }
    }

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

    private var todayMemoryEvents: Int {
        todayRecords.reduce(0) { sum, record in
            sum + (record.memoryHitIDs?.count ?? 0)
                + (record.replacementRuleIDs?.count ?? 0)
                + (record.snippetIDs?.count ?? 0)
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func beginCorrection(_ record: DictationRecord) {
        correctionObserved = record.rawText ?? record.text
        correctionCorrected = record.text
        correctionRecord = record
    }

    private func correctionSheet(_ record: DictationRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            CommandPageHeader(
                eyebrow: "Memory",
                title: "Learn Correction",
                subtitle: "Teach Sadaa once so this wording is handled deterministically next time."
            )
            TextField("Heard", text: $correctionObserved)
                .textFieldStyle(.roundedBorder)
            TextField("Write", text: $correctionCorrected)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") {
                    correctionRecord = nil
                }
                Button("Save to Memory") {
                    viewModel.languageMemory.learnCorrection(
                        observed: correctionObserved,
                        corrected: correctionCorrected
                    )
                    correctionRecord = nil
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.navy)
                .disabled(correctionObserved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          correctionCorrected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(Theme.cream)
    }
}

private struct RecentCommandRow: View {
    let record: DictationRecord
    let onCopy: () -> Void
    let onSendToScratchpad: () -> Void
    let onLearn: () -> Void
    let onReprocess: () -> Void

    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(record.text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(3)
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    metadata(icon: "clock", text: PageFormat.relativeTime(record.createdAt))
                    metadata(icon: "waveform", text: record.provider)
                    if memoryCount > 0 {
                        metadata(icon: "sparkles", text: "\(memoryCount) memory")
                    }
                }
            }
            Spacer(minLength: 10)
            HStack(spacing: 6) {
                actionButton(copied ? "checkmark" : "doc.on.doc", copied ? "Copied" : "Copy") {
                    onCopy()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                }
                actionButton("note.text", "Send to Scratchpad", onSendToScratchpad)
                actionButton("graduationcap", "Learn correction", onLearn)
                actionButton("arrow.clockwise", "Reprocess", onReprocess)
            }
        }
        .padding(13)
        .background(hovering ? Theme.cream : Theme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(hovering ? Theme.gold.opacity(0.42) : Theme.line, lineWidth: 1)
        )
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.86), value: hovering)
        .animation(.spring(response: 0.25, dampingFraction: 0.86), value: copied)
    }

    private var memoryCount: Int {
        (record.memoryHitIDs?.count ?? 0)
            + (record.replacementRuleIDs?.count ?? 0)
            + (record.snippetIDs?.count ?? 0)
    }

    private func metadata(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Theme.muted)
    }

    private func actionButton(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(title == "Copied" ? Theme.sage : Theme.navy)
        .background(Theme.white, in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Theme.navy.opacity(0.18), lineWidth: 1)
        )
        .help(title)
    }
}

private struct LearningPulseRow: View {
    let suggestion: MemorySuggestion

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(suggestion.proposed)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(suggestion.evidenceCount) observations from \(sourceTitle)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1)
        )
    }

    private var icon: String {
        switch suggestion.kind {
        case .term: return "textformat"
        case .replacement: return "arrow.left.arrow.right"
        case .snippetCandidate: return "text.badge.plus"
        }
    }

    private var sourceTitle: String {
        switch suggestion.source {
        case .formatter: return "formatter"
        case .historyCorrection: return "history"
        case .manualImport: return "import"
        case .reprocess: return "reprocess"
        }
    }
}
