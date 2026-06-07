import SwiftUI
import AppKit
import SadaaCore

/// Searchable list of every dictation, read straight off the store. Each row
/// can copy its text to the pasteboard.
struct HistoryPage: View {
    @ObservedObject var viewModel: SadaaViewModel
    @State private var query = ""

    /// Reading `viewModel.recent.count` ties this view's identity to the
    /// published property, so the list re-renders when a new dictation lands.
    private var results: [DictationRecord] {
        _ = viewModel.recent.count
        return viewModel.historyStore.search(query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("History")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.charcoal)

            searchField

            content
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(Theme.charcoal.opacity(0.5))
            TextField("Search dictations", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.charcoal)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Theme.creamSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Theme.gold.opacity(0.2), lineWidth: 1)
        )
        .frame(maxWidth: 520)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let records = results
        if records.isEmpty {
            Text(query.isEmpty ? "No dictations yet." : "No matching dictations.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.charcoal.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(records) { record in
                        row(record)
                    }
                }
                .frame(maxWidth: 640, alignment: .leading)
            }
        }
    }

    private func row(_ record: DictationRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text(record.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.charcoal)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Copy") { copy(record.text) }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.navy)
            }

            HStack(spacing: 8) {
                Text(PageFormat.relativeTime(record.createdAt))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.charcoal.opacity(0.5))
                if let language = record.language, !language.isEmpty {
                    tag(language)
                }
                tag(record.provider)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.creamSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1)
        )
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.sage)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Theme.sage.opacity(0.12))
            )
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
