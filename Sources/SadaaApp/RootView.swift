import SwiftUI
import SadaaCore

/// Sections in the main window sidebar. String-raw + Identifiable makes it
/// usable directly as the selection value for `List(selection:)`.
enum SidebarSection: String, CaseIterable, Identifiable {
    case home, dictionary, notes, history, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .dictionary: return "Dictionary"
        case .notes: return "Notes"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .dictionary: return "character.book.closed"
        case .notes: return "note.text"
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
        // Sadaa wears a fixed light cream/navy brand. Pin the window to the
        // light scheme so default text resolves dark and stays readable on
        // cream even when macOS is in Dark Mode.
        .preferredColorScheme(.light)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        // Plain buttons, not List(selection:), so the selection is our own gold
        // pill rather than the macOS system-accent highlight.
        VStack(alignment: .leading, spacing: 4) {
            brand
            ForEach(SidebarSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    SidebarItem(
                        title: section.title,
                        systemImage: section.systemImage,
                        isSelected: selection == section
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
            Spacer(minLength: 0)
        }
        .frame(minWidth: 200, maxHeight: .infinity, alignment: .top)
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
            DictionaryPage(viewModel: viewModel)
        case .notes:
            NotesPage(viewModel: viewModel)
        case .history:
            HistoryPage(viewModel: viewModel)
        case .settings:
            SettingsPage(settings: settings, viewModel: viewModel)
        }
    }
}
