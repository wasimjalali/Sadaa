import SwiftUI
import AppKit
import SadaaCore

/// Transcript timeline with a focused inspector for review, correction, and recovery.
struct HistoryPage: View {
    @ObservedObject var viewModel: SadaaViewModel

    @State private var query = ""
    @State private var selectedRecordID: UUID?
    @State private var showClearConfirm = false
    @State private var correctionRecord: DictationRecord?
    @State private var correctionObserved = ""
    @State private var correctionCorrected = ""

    /// Ties rendering to the published recent list while keeping History sourced
    /// from the durable store.
    private var results: [DictationRecord] {
        _ = viewModel.recent.count
        return viewModel.historyStore.search(query)
    }

    private var allRecords: [DictationRecord] {
        viewModel.historyStore.all()
    }

    private var selectedRecord: DictationRecord? {
        if let selectedRecordID, let match = results.first(where: { $0.id == selectedRecordID }) {
            return match
        }
        return results.first
    }

    private var memoryTouchCount: Int {
        allRecords.reduce(0) { total, record in
            total
            + (record.memoryHitIDs?.count ?? 0)
            + (record.replacementRuleIDs?.count ?? 0)
            + (record.snippetIDs?.count ?? 0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                metricsStrip
                searchAndControls
                workspace
            }
            .padding(30)
            .frame(maxWidth: 1180, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Theme.cream)
        .confirmationDialog(
            "Delete all history? This can't be undone.",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete all", role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                    viewModel.historyStore.clear()
                    selectedRecordID = nil
                    viewModel.refreshRecent()
                    viewModel.refreshCost()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $correctionRecord) { record in
            correctionSheet(record)
        }
    }

    private var header: some View {
        CommandPageHeader(
            eyebrow: "Transcript Timeline",
            title: "History",
            subtitle: "Review every dictation, recover missed text, and teach Language Memory from the places where accuracy matters."
        ) {
            VStack(alignment: .trailing, spacing: 8) {
                PremiumStatusBadge(
                    icon: "chart.bar.fill",
                    text: "\(PageFormat.minutes(viewModel.monthlyCost.minutes)) this month",
                    tint: Theme.navy
                )
                PremiumStatusBadge(
                    icon: "creditcard",
                    text: PageFormat.dollars(viewModel.monthlyCost.cost),
                    tint: Theme.gold
                )
            }
        }
    }

    private var metricsStrip: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
            spacing: 12
        ) {
            CommandMetric(icon: "waveform", value: "\(allRecords.count)", label: "saved transcripts", tint: Theme.navy)
            CommandMetric(icon: "magnifyingglass", value: "\(results.count)", label: query.isEmpty ? "visible" : "matches", tint: Theme.sage)
            CommandMetric(icon: "sparkles", value: "\(memoryTouchCount)", label: "memory touches", tint: Theme.gold)
            CommandMetric(icon: "clock", value: PageFormat.minutes(viewModel.monthlyCost.minutes), label: "monthly audio", tint: Theme.navy)
        }
    }

    private var searchAndControls: some View {
        CommandPanel {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    historySearchField
                        .frame(maxWidth: 560)
                    historyFilterBadge
                    Spacer(minLength: 10)
                    clearHistoryButton
                }

                VStack(alignment: .leading, spacing: 12) {
                    historySearchField
                    HStack(spacing: 10) {
                        historyFilterBadge
                        Spacer(minLength: 8)
                        clearHistoryButton
                    }
                }
            }
        }
    }

    private var workspace: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                timelinePanel
                    .frame(minWidth: 540)
                    .layoutPriority(1)

                inspectorPanel
                    .frame(width: 340)
            }

            VStack(alignment: .leading, spacing: 18) {
                timelinePanel
                    .frame(maxWidth: .infinity)
                inspectorPanel
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var historySearchField: some View {
        PremiumSearchField(placeholder: "Search transcripts, providers, languages, or AI terms", text: $query)
    }

    private var historyFilterBadge: some View {
        PremiumStatusBadge(
            icon: "line.3.horizontal.decrease.circle",
            text: query.isEmpty ? "All transcripts" : "\(results.count) filtered",
            tint: Theme.sage
        )
    }

    private var clearHistoryButton: some View {
        Button {
            showClearConfirm = true
        } label: {
            Label("Clear history", systemImage: "trash")
                .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(HistoryUtilityButtonStyle(tint: Theme.red))
        .disabled(allRecords.isEmpty)
        .opacity(allRecords.isEmpty ? 0.45 : 1)
    }

    private var timelinePanel: some View {
        CommandPanel("Transcript Timeline", icon: "clock.arrow.circlepath") {
            if results.isEmpty {
                CommandEmptyState(
                    icon: query.isEmpty ? "text.bubble" : "magnifyingglass",
                    title: query.isEmpty ? "No transcripts yet" : "No matching transcripts",
                    detail: query.isEmpty
                    ? "Start dictating and Sadaa will build a searchable local archive here."
                    : "Try a different spelling, product name, framework, or workflow phrase."
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(groupedRecords(results), id: \.title) { group in
                        HistoryDaySection(
                            group: group,
                            selectedRecordID: selectedRecord?.id,
                            onSelect: { selectedRecordID = $0.id },
                            onCopy: { copy($0.text) },
                            onSendToScratchpad: { viewModel.sendToScratchpad($0) },
                            onReprocess: { reprocess($0) },
                            onLearn: { beginCorrection(for: $0) },
                            onDelete: { delete($0) }
                        )
                    }
                }
            }
        }
    }

    private var inspectorPanel: some View {
        CommandPanel("Transcript Inspector", icon: "doc.text.magnifyingglass") {
            if let selectedRecord {
                VStack(alignment: .leading, spacing: 16) {
                    inspectorTranscript(selectedRecord)
                    inspectorMetadata(selectedRecord)
                    inspectorActions(selectedRecord)
                }
            } else {
                CommandEmptyState(
                    icon: "doc.text.magnifyingglass",
                    title: "Nothing selected",
                    detail: "Pick a transcript to inspect text, metadata, and Language Memory evidence."
                )
            }
        }
    }

    private func inspectorTranscript(_ record: DictationRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Final Text")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.navy)
                Spacer()
                Text(HistoryFormat.dateTime(record.createdAt))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }

            Text(record.text)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))

            if let rawText = record.rawText,
               !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               rawText != record.text {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Heard")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.muted)
                    Text(rawText)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(6)
                        .textSelection(.enabled)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
            }
        }
    }

    private func inspectorMetadata(_ record: DictationRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Evidence")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.navy)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                inspectorTile("Provider", record.provider)
                inspectorTile("Language", record.language?.isEmpty == false ? record.language ?? "Auto" : "Auto")
                inspectorTile("Duration", HistoryFormat.duration(record.durationSeconds))
                inspectorTile("Mode", HistoryFormat.mode(record.mode))
                inspectorTile("Cost", record.estimatedCost.map(PageFormat.dollars) ?? "$0.00")
                inspectorTile("Memory", "\(memoryCount(for: record)) hits")
            }

            HStack(spacing: 6) {
                if let model = record.modelDeployment, !model.isEmpty {
                    HistoryBadge(icon: "cpu", text: model, tint: Theme.navy)
                }
                if record.mode == .raw {
                    HistoryBadge(icon: "doc.plaintext", text: "Raw", tint: Theme.warning)
                } else {
                    HistoryBadge(icon: "sparkles", text: "Formatted", tint: Theme.sage)
                }
            }
        }
    }

    private func inspectorTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
    }

    private func inspectorActions(_ record: DictationRecord) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HistoryActionButton(icon: "graduationcap.fill", title: "Learn Correction", tint: Theme.gold) {
                beginCorrection(for: record)
            }
            HistoryActionButton(icon: "arrow.clockwise", title: "Reprocess With Memory", tint: Theme.navy) {
                reprocess(record)
            }
            HistoryActionButton(icon: "note.text", title: "Send To Scratchpad", tint: Theme.sage) {
                viewModel.sendToScratchpad(record)
            }
            HistoryActionButton(icon: "doc.on.doc", title: "Copy Transcript", tint: Theme.navy) {
                copy(record.text)
            }
            HistoryActionButton(icon: "trash", title: "Delete Transcript", tint: Theme.red) {
                delete(record)
            }
        }
    }

    private func beginCorrection(for record: DictationRecord) {
        correctionObserved = record.rawText ?? record.text
        correctionCorrected = record.text
        correctionRecord = record
    }

    private func reprocess(_ record: DictationRecord) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            viewModel.reprocessHistoryWithLanguageMemory(record)
        }
    }

    private func delete(_ record: DictationRecord) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            viewModel.historyStore.delete(id: record.id)
            if selectedRecordID == record.id {
                selectedRecordID = nil
            }
            viewModel.refreshRecent()
            viewModel.refreshCost()
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func correctionSheet(_ record: DictationRecord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            CommandPageHeader(
                eyebrow: "Language Memory",
                title: "Learn Correction",
                subtitle: "Save the exact correction so future transcripts in this niche stop repeating the same mistake."
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Heard")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.muted)
                TextField("What Sadaa heard", text: $correctionObserved)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Correct")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.muted)
                TextField("How it should be written", text: $correctionCorrected)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    correctionRecord = nil
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.muted)
                .clickableCursor()

                Button {
                    viewModel.languageMemory.learnCorrection(
                        observed: correctionObserved,
                        corrected: correctionCorrected
                    )
                    correctionRecord = nil
                } label: {
                    Label("Save Correction", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(HistoryUtilityButtonStyle(tint: Theme.navy))
                .disabled(correctionObserved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          correctionCorrected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(Theme.cream)
    }

    private func memoryCount(for record: DictationRecord) -> Int {
        (record.memoryHitIDs?.count ?? 0)
        + (record.replacementRuleIDs?.count ?? 0)
        + (record.snippetIDs?.count ?? 0)
    }

    fileprivate struct DayGroup {
        let title: String
        let records: [DictationRecord]
    }

    private func groupedRecords(_ records: [DictationRecord]) -> [DayGroup] {
        let calendar = Calendar.current
        var order: [String] = []
        var buckets: [String: [DictationRecord]] = [:]

        for record in records {
            let title = HistoryFormat.sectionTitle(for: record.createdAt, calendar: calendar)
            if buckets[title] == nil {
                buckets[title] = []
                order.append(title)
            }
            buckets[title]?.append(record)
        }

        return order.map { DayGroup(title: $0, records: buckets[$0] ?? []) }
    }
}

private struct HistoryDaySection: View {
    let group: HistoryPage.DayGroup
    let selectedRecordID: UUID?
    let onSelect: (DictationRecord) -> Void
    let onCopy: (DictationRecord) -> Void
    let onSendToScratchpad: (DictationRecord) -> Void
    let onReprocess: (DictationRecord) -> Void
    let onLearn: (DictationRecord) -> Void
    let onDelete: (DictationRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Text(group.title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.gold)
                Rectangle()
                    .fill(Theme.line)
                    .frame(height: 1)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(group.records) { record in
                    HistoryTimelineRow(
                        record: record,
                        selected: selectedRecordID == record.id,
                        onSelect: { onSelect(record) },
                        onCopy: { onCopy(record) },
                        onSendToScratchpad: { onSendToScratchpad(record) },
                        onReprocess: { onReprocess(record) },
                        onLearn: { onLearn(record) },
                        onDelete: { onDelete(record) }
                    )
                }
            }
        }
    }
}

private struct HistoryTimelineRow: View {
    let record: DictationRecord
    let selected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onSendToScratchpad: () -> Void
    let onReprocess: () -> Void
    let onLearn: () -> Void
    let onDelete: () -> Void

    @State private var copied = false
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Circle()
                    .fill(selected ? Theme.gold : Theme.navy.opacity(0.26))
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(Theme.line)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .padding(.top, 14)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(HistoryFormat.time(record.createdAt))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.navy)
                        Text(record.text)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(2)
                            .lineLimit(selected ? 6 : 3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    HStack(spacing: 6) {
                        actionIcon(copied ? "checkmark" : "doc.on.doc", help: copied ? "Copied" : "Copy") {
                            onCopy()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) { copied = false }
                            }
                        }
                        actionIcon("note.text", help: "Send to Scratchpad", action: onSendToScratchpad)
                        actionIcon("arrow.clockwise", help: "Reprocess with Memory", action: onReprocess)
                        actionIcon("graduationcap", help: "Learn correction", action: onLearn)
                        actionIcon("trash", help: "Delete", tint: Theme.red, action: onDelete)
                    }
                    .opacity(hovering || selected ? 1 : 0.72)
                }

                HStack(spacing: 6) {
                    HistoryBadge(icon: "waveform", text: record.provider, tint: Theme.sage)
                    HistoryBadge(icon: "clock", text: HistoryFormat.duration(record.durationSeconds), tint: Theme.navy)
                    if let language = record.language, !language.isEmpty {
                        HistoryBadge(icon: "globe", text: language, tint: Theme.navy)
                    }
                    if let estimatedCost = record.estimatedCost {
                        HistoryBadge(icon: "creditcard", text: PageFormat.dollars(estimatedCost), tint: Theme.gold)
                    }
                    let touches = (record.memoryHitIDs?.count ?? 0)
                    + (record.replacementRuleIDs?.count ?? 0)
                    + (record.snippetIDs?.count ?? 0)
                    if touches > 0 {
                        HistoryBadge(icon: "sparkles", text: "\(touches) memory", tint: Theme.gold)
                    }
                    if record.mode == .raw {
                        HistoryBadge(icon: "doc.plaintext", text: "Raw", tint: Theme.warning)
                    }
                }
            }
            .padding(14)
            .background(selected ? Theme.white : Theme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? Theme.gold.opacity(0.74) : Theme.line, lineWidth: selected ? 1.5 : 1)
            )
            .shadow(color: Theme.navy.opacity(selected ? 0.08 : 0.03), radius: selected ? 16 : 8, y: 6)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .clickableCursor()
            .onHover { isOn in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    hovering = isOn
                }
            }
        }
    }

    private func actionIcon(_ systemImage: String,
                            help: String,
                            tint: Color = Theme.navy,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .background(Theme.white, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(tint.opacity(0.24), lineWidth: 1))
        .help(help)
        .clickableCursor()
    }
}

private struct HistoryActionButton: View {
    let icon: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(tint.opacity(0.24), lineWidth: 1))
        .clickableCursor()
    }
}

private struct HistoryBadge: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(tint.opacity(0.1), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.2), lineWidth: 1))
    }
}

private struct HistoryUtilityButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(configuration.isPressed ? 0.18 : 0.09), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(tint.opacity(0.25), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .clickableCursor()
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

private enum HistoryFormat {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }()

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let monthDayYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func dateTime(_ date: Date) -> String {
        dateTimeFormatter.string(from: date)
    }

    static func duration(_ seconds: Double?) -> String {
        guard let seconds else { return "0:00" }
        let clamped = max(0, Int(seconds.rounded()))
        return "\(clamped / 60):\(String(format: "%02d", clamped % 60))"
    }

    static func mode(_ mode: FormattingMode?) -> String {
        switch mode {
        case .raw: return "Raw"
        case .formatted: return "Formatted"
        case .none: return "Raw"
        }
    }

    static func sectionTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return monthDayFormatter.string(from: date)
        }
        return monthDayYearFormatter.string(from: date)
    }
}
