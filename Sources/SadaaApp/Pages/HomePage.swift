import SwiftUI
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

/// The landing page: the mic control, connection and language status, and a
/// short list of the most recent dictations.
struct HomePage: View {
    @ObservedObject var viewModel: SadaaViewModel

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 8)

            MicButton(state: viewModel.dictationState) { viewModel.toggle() }

            statusBlock

            recentSection

            Spacer(minLength: 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Status

    private var statusBlock: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.azureConfigured ? Theme.sage : Theme.gold)
                    .frame(width: 9, height: 9)
                Text(viewModel.azureConfigured
                     ? "Azure connected"
                     : "Not configured. Open Settings.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.charcoal)
            }

            Text("Language: \(PageFormat.languageLabel(viewModel.languagePin))")
                .font(.system(size: 12))
                .foregroundStyle(Theme.charcoal.opacity(0.65))
        }
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.charcoal.opacity(0.7))

            if viewModel.recent.isEmpty {
                Text("Your dictations will appear here.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.charcoal.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recent.prefix(5)) { record in
                        recentRow(record)
                    }
                }
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private func recentRow(_ record: DictationRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.charcoal)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(PageFormat.relativeTime(record.createdAt))
                .font(.system(size: 11))
                .foregroundStyle(Theme.charcoal.opacity(0.5))
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
}
