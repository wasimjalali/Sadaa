import SwiftUI
import AppKit
import SadaaCore

struct HistoryPage: View {
    @ObservedObject var viewModel: SadaaViewModel

    @State private var query = ""
    @State private var selectedID: UUID?
    @State private var showClearConfirm = false
    @State private var correctionRecord: DictationRecord?
    @State private var correctionObserved = ""
    @State private var correctionCorrected = ""

    private var records: [DictationRecord] {
        _ = viewModel.recent.count
        return viewModel.historyStore.search(query)
    }

    private var selectedRecord: DictationRecord? {
        if let selectedID, let selected = records.first(where: { $0.id == selectedID }) {
            return selected
        }
        return records.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            workspace
        }
        .padding(32)
        .frame(maxWidth: 1180, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
        .confirmationDialog(
            "Delete all transcripts? This cannot be undone.",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete all transcripts", role: .destructive) {
                viewModel.historyStore.clear()
                selectedID = nil
                viewModel.refreshRecent()
                viewModel.refreshCost()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $correctionRecord) { record in correctionSheet(record) }
    }

    private var header: some View {
        CommandPageHeader(
            title: "Library",
            subtitle: "Search, copy and improve your previous dictations. Everything stays local on this Mac."
        ) {
            Menu {
                Button("Delete all transcripts", role: .destructive) { showClearConfirm = true }
                    .disabled(viewModel.historyStore.all().isEmpty)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 34)
            .help("Library options")
            .clickableCursor()
        }
    }

    private var workspace: some View {
        HStack(alignment: .top, spacing: 18) {
            transcriptList.frame(width: 300)
            transcriptDetail.frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .layoutPriority(1)
    }

    private var transcriptList: some View {
        VStack(alignment: .leading, spacing: 12) {
            PremiumSearchField(placeholder: "Search transcripts", text: $query)

            if records.isEmpty {
                CommandEmptyState(
                    icon: query.isEmpty ? "text.page" : "magnifyingglass",
                    title: query.isEmpty ? "No transcripts yet" : "No matching transcripts",
                    detail: query.isEmpty
                        ? "Your next dictation will appear here automatically."
                        : "Try a shorter word or a different spelling."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(grouped(records), id: \.day) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(dayTitle(group.day))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.muted)
                                    .padding(.horizontal, 4)
                                VStack(spacing: 4) {
                                    ForEach(group.records) { record in
                                        transcriptRow(record)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.surfaceSubtle, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxHeight: .infinity)
    }

    private func transcriptRow(_ record: DictationRecord) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Button {
                selectedID = record.id
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(time(record.createdAt))
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(selectedRecord?.id == record.id ? Theme.brand : Theme.muted)
                        Spacer()
                        if let duration = record.durationSeconds {
                            Text(durationText(duration))
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    Text(record.text)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .clickableCursor()

            Button {
                copy(record.text)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(PremiumIconButtonStyle())
            .help("Copy transcript")
        }
        .padding(10)
        .background(
            selectedRecord?.id == record.id ? Theme.surface : Color.clear,
            in: RoundedRectangle(cornerRadius: 9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(selectedRecord?.id == record.id ? Theme.line : Color.clear, lineWidth: 1)
        )
    }

    private var transcriptDetail: some View {
        Group {
            if let record = selectedRecord {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        detailHeader(record)
                        Text(record.text)
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(5)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Divider().overlay(Theme.line)
                        detailActions(record)
                        technicalDetails(record)
                    }
                    .padding(24)
                }
            } else {
                CommandEmptyState(
                    icon: "text.page",
                    title: "Select a transcript",
                    detail: "Choose an item from the library to read or reuse it."
                )
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
    }

    private func detailHeader(_ record: DictationRecord) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(fullDate(record.createdAt))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text([record.language, record.durationSeconds.map(durationText)].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button("Copy") { copy(record.text) }
                .buttonStyle(.bordered)
                .tint(Theme.brand)
                .clickableCursor()
        }
    }

    private func detailActions(_ record: DictationRecord) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { actionButtons(record) }
                .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 8) { actionButtons(record) }
        }
    }

    @ViewBuilder
    private func actionButtons(_ record: DictationRecord) -> some View {
        Button("Learn correction") { beginCorrection(record) }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand)
            .clickableCursor()
        Button("Send to notes") { viewModel.sendToScratchpad(record) }
            .buttonStyle(.bordered)
            .tint(Theme.brand)
            .clickableCursor()
        Button("Reprocess") { viewModel.reprocessHistoryWithLanguageMemory(record) }
            .buttonStyle(.bordered)
            .tint(Theme.brand)
            .clickableCursor()
        Button("Delete", role: .destructive) { delete(record) }
            .buttonStyle(.borderless)
            .clickableCursor()
    }

    private func technicalDetails(_ record: DictationRecord) -> some View {
        DisclosureGroup("Details") {
            VStack(alignment: .leading, spacing: 12) {
                if let raw = record.rawText, raw != record.text, !raw.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Original transcript")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                        Text(raw)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            .textSelection(.enabled)
                    }
                }
                detailLine("Provider", record.provider)
                if let model = record.modelDeployment, !model.isEmpty { detailLine("Model", model) }
                detailLine("Dictionary matches", "\(memoryCount(record))")
                if let cost = record.estimatedCost { detailLine("Estimated cost", PageFormat.dollars(cost)) }
            }
            .padding(.top, 10)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Theme.muted)
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).foregroundStyle(Theme.ink).textSelection(.enabled)
        }
        .font(.system(size: 12))
    }

    private func correctionSheet(_ record: DictationRecord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Learn a correction")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Save what Sadaa heard and the spelling you want next time.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)

            VStack(alignment: .leading, spacing: 6) {
                Text("Heard").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
                TextField("What Sadaa heard", text: $correctionObserved).premiumInputChrome()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Write instead").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
                TextField("Correct spelling", text: $correctionCorrected).premiumInputChrome()
            }
            HStack {
                Spacer()
                Button("Cancel") { correctionRecord = nil }
                    .clickableCursor()
                Button("Save correction") {
                    viewModel.languageMemory.learnCorrection(
                        observed: correctionObserved,
                        corrected: correctionCorrected
                    )
                    correctionRecord = nil
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brand)
                .clickableCursor()
                .disabled(correctionObserved.isEmpty || correctionCorrected.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(Theme.surface)
    }

    private func beginCorrection(_ record: DictationRecord) {
        correctionObserved = record.rawText ?? record.text
        correctionCorrected = record.text
        correctionRecord = record
    }

    private func delete(_ record: DictationRecord) {
        viewModel.historyStore.delete(id: record.id)
        if selectedID == record.id { selectedID = nil }
        viewModel.refreshRecent()
        viewModel.refreshCost()
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func grouped(_ records: [DictationRecord]) -> [(day: Date, records: [DictationRecord])] {
        let groups = Dictionary(grouping: records) { Calendar.current.startOfDay(for: $0.createdAt) }
        return groups.map { ($0.key, $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.day > $1.day }
    }

    private func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
    private func fullDate(_ date: Date) -> String { date.formatted(date: .abbreviated, time: .shortened) }

    private func durationText(_ seconds: Double) -> String {
        if seconds < 60 { return "\(Int(seconds.rounded())) sec" }
        return String(format: "%.1f min", seconds / 60)
    }

    private func memoryCount(_ record: DictationRecord) -> Int {
        (record.memoryHitIDs?.count ?? 0) +
        (record.replacementRuleIDs?.count ?? 0) +
        (record.snippetIDs?.count ?? 0)
    }
}
