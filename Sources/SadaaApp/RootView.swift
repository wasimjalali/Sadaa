import SwiftUI
import SadaaCore

/// Sections in the main window sidebar. String-raw + Identifiable makes it
/// usable directly as the selection value for `List(selection:)`.
enum SidebarSection: String, CaseIterable, Identifiable {
    case home, dictionary, history, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .dictionary: return "Dictionary"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .dictionary: return "character.book.closed"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

/// The windowed shell: a navy sidebar over a cream detail pane. Each section
/// resolves to a dedicated page composed from the shared view model.
struct RootView: View {
    @ObservedObject var viewModel: SadaaViewModel
    let settings: AppSettings

    @State private var selection: SidebarSection = .home

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.cream)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
            List(selection: $selection) {
                ForEach(SidebarSection.allCases) { section in
                    SidebarItem(
                        title: section.title,
                        systemImage: section.systemImage,
                        isSelected: selection == section
                    )
                    .tag(section)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.sidebar)
        }
        .frame(minWidth: 200)
        .background(Theme.navy)
    }

    private var brand: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.gold)
            Text("Sadaa")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.cream)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .home:
            HomePage(viewModel: viewModel)
        case .dictionary:
            DictionaryPage()
        case .history:
            HistoryPage(viewModel: viewModel)
        case .settings:
            SettingsPage(settings: settings, viewModel: viewModel)
        }
    }
}
