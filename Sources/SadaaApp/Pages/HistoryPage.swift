import SwiftUI
import AppKit
import SadaaCore

/// Searchable, day-grouped list of every dictation, read straight off the store.
/// Each row can copy its text or delete itself, and the whole list can be cleared.
struct HistoryPage: View {
    @ObservedObject var viewModel: SadaaViewModel
    @State private var query = ""
    @State private var showClearConfirm = false
    @FocusState private var searchFocused: Bool

    /// Reading `viewModel.recent.count` ties this view's identity to the
    /// published property, so the list re-renders when a new dictation lands.
    /// We re-derive everything from the store on every body evaluation, so a
    /// dictation that arrives mid-search still shows up.
    private var results: [DictationRecord] {
        _ = viewModel.recent.count
        return viewModel.historyStore.search(query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            HStack(alignment: .center, spacing: 12) {
                searchField
                Spacer(minLength: 8)
                clearAllButton
            }
            .frame(maxWidth: 640)

            matchesLine

            content
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog(
            "Delete all history? This can't be undone.",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete all", role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.historyStore.clear()
                    viewModel.refreshRecent()
                    viewModel.refreshCost()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("History")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.charcoal)

            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.gold)
                Text("This month: ")
                    .foregroundStyle(Theme.charcoal.opacity(0.55))
                + Text(PageFormat.minutes(viewModel.monthlyCost.minutes))
                    .foregroundStyle(Theme.charcoal.opacity(0.8))
                Text(", about ")
                    .foregroundStyle(Theme.charcoal.opacity(0.55))
                + Text(PageFormat.dollars(viewModel.monthlyCost.cost))
                    .foregroundStyle(Theme.charcoal.opacity(0.8))
            }
            .font(.system(size: 12, weight: .medium))
            .contentTransition(.numericText())
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.monthlyCost.minutes)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.monthlyCost.cost)
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(searchFocused ? Theme.gold : Theme.charcoal.opacity(0.5))
            TextField("Search dictations", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.charcoal)
                .focused($searchFocused)
            if !query.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        query = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.charcoal.opacity(0.35))
                }
                .buttonStyle(.borderless)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Theme.creamSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(
                    searchFocused ? Theme.gold.opacity(0.7) : Theme.gold.opacity(0.2),
                    lineWidth: searchFocused ? 1.5 : 1
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: searchFocused)
        .frame(maxWidth: 420)
    }

    private var clearAllButton: some View {
        Button {
            showClearConfirm = true
        } label: {
            Label("Clear all", systemImage: "trash")
                .font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(ClearAllButtonStyle())
        .opacity(viewModel.historyStore.all().isEmpty ? 0 : 1)
        .disabled(viewModel.historyStore.all().isEmpty)
    }

    private var matchesLine: some View {
        let count = results.count
        return Group {
            if !query.isEmpty {
                Text("\(count) \(count == 1 ? "match" : "matches")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.charcoal.opacity(0.5))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: count)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let records = results
        if records.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18, pinnedViews: []) {
                    ForEach(groupedRecords(records), id: \.title) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel(group.title)
                            ForEach(group.records) { record in
                                row(record)
                                    .transition(.asymmetric(
                                        insertion: .opacity,
                                        removal: .scale(scale: 0.95).combined(with: .opacity)
                                    ))
                            }
                        }
                    }
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(.bottom, 12)
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.0)
            .foregroundStyle(Theme.gold300)
            .padding(.top, 2)
    }

    // MARK: - Empty states

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: query.isEmpty ? "text.bubble" : "magnifyingglass")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(Theme.gold300)
                .symbolEffect(.bounce, value: query.isEmpty)
            Text(query.isEmpty ? "No dictations yet. Start talking and they'll land here." : "No matches. Try a different word.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.charcoal.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Row

    private func row(_ record: DictationRecord) -> some View {
        HistoryRow(
            record: record,
            onCopy: { copy(record.text) },
            onDelete: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.historyStore.delete(id: record.id)
                    viewModel.refreshRecent()
                    viewModel.refreshCost()
                }
            }
        )
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Grouping

    private struct DayGroup {
        let title: String
        let records: [DictationRecord]
    }

    private func groupedRecords(_ records: [DictationRecord]) -> [DayGroup] {
        let calendar = Calendar.current
        var order: [String] = []
        var buckets: [String: [DictationRecord]] = [:]

        for record in records {
            let title = HistoryPage.sectionTitle(for: record.createdAt, calendar: calendar)
            if buckets[title] == nil {
                buckets[title] = []
                order.append(title)
            }
            buckets[title]?.append(record)
        }

        return order.map { DayGroup(title: $0, records: buckets[$0] ?? []) }
    }

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let monthDayYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private static func sectionTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return monthDayFormatter.string(from: date)
        }
        return monthDayYearFormatter.string(from: date)
    }
}

// MARK: - Row view

/// One dictation row. Hover reveals Copy and Delete; Copy morphs to a sage
/// checkmark for a moment after it fires.
private struct HistoryRow: View {
    let record: DictationRecord
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text(record.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.charcoal)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if hovering || copied {
                    HStack(spacing: 6) {
                        copyButton
                        deleteButton
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }

            HStack(spacing: 6) {
                capsule(PageFormat.relativeTime(record.createdAt), icon: "clock")
                if let language = record.language, !language.isEmpty {
                    capsule(language, icon: "globe")
                }
                capsule(record.provider, icon: "waveform")
                if let cost = record.estimatedCost {
                    capsule(PageFormat.dollars(cost), icon: "creditcard")
                }
                // Diagnosability: which pipeline produced this text. Prompt Mode
                // shows its target; Raw flags pure transcription (deliberate or
                // a formatter fallback). Plain formatted rows stay uncluttered.
                if record.mode == .prompt {
                    capsule("Prompt → \(record.promptTarget ?? "?")",
                            icon: "wand.and.stars")
                } else if record.mode == .raw {
                    capsule("Raw", icon: "doc.plaintext")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.creamSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    hovering ? Theme.gold.opacity(0.4) : Theme.gold.opacity(0.18),
                    lineWidth: 1
                )
        )
        .shadow(color: Theme.navy.opacity(hovering ? 0.06 : 0), radius: 6, y: 2)
        .onHover { isOn in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                hovering = isOn
            }
        }
    }

    private var copyButton: some View {
        Button {
            onCopy()
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
            }
            .foregroundStyle(copied ? Theme.sage : Theme.navy)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.charcoal.opacity(0.55))
        }
        .buttonStyle(PressableButtonStyle())
        .help("Delete this dictation")
    }

    private func capsule(_ text: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(Theme.sage)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(Theme.sage.opacity(0.12))
        )
    }
}

// MARK: - Button styles

/// Subtle press-down scale for borderless icon/text buttons.
private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// Quiet bordered button for the Clear all control, with hover and press feedback.
private struct ClearAllButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.charcoal.opacity(0.7))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(hovering ? Theme.charcoal.opacity(0.06) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Theme.charcoal.opacity(0.18), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .onHover { isOn in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { hovering = isOn }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
