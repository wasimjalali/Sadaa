import AppKit
import SwiftUI
import SadaaCore

/// Sections in the main window sidebar. String-raw + Identifiable makes it
/// usable directly as the selection value for `List(selection:)`.
enum SidebarSection: String, CaseIterable, Identifiable {
    case home, languageMemory, scratchpad, history, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .languageMemory: return "Memory"
        case .scratchpad: return "Scratchpad"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .languageMemory: return "text.book.closed"
        case .scratchpad: return "note.text"
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
        VStack(alignment: .leading, spacing: 6) {
            brand
            Text("VOICE SYSTEM")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.gold.opacity(0.86))
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 2)
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
                .clickableCursor()
                .padding(.horizontal, 10)
            }
            Spacer(minLength: 0)
            footer
        }
        .frame(minWidth: 210, maxWidth: 210, maxHeight: .infinity, alignment: .top)
        .background(
            Rectangle()
                .fill(Theme.navy800)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Theme.gold.opacity(0.18))
                        .frame(width: 1)
                }
        )
    }

    private var brand: some View {
        HStack(spacing: 10) {
            BrandMark()
            VStack(alignment: .leading, spacing: 1) {
                Text("Sadaa")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.white)
                Text("AI Dictation")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.cream.opacity(0.68))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.hotkeyActive ? Theme.sage : Theme.gold)
                    .frame(width: 7, height: 7)
                Text(viewModel.hotkeyActive ? "Hotkeys active" : "Needs access")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.cream.opacity(0.78))
            }
            Text("Local-first voice workspace")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.cream.opacity(0.48))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.gold.opacity(0.14), lineWidth: 1)
        )
        .padding(12)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .home:
            HomePage(viewModel: viewModel)
        case .languageMemory:
            LanguageMemoryPage(viewModel: viewModel.languageMemory)
        case .scratchpad:
            ScratchpadPage(viewModel: viewModel)
        case .history:
            HistoryPage(viewModel: viewModel)
        case .settings:
            SettingsPage(settings: settings, viewModel: viewModel)
        }
    }
}

private struct BrandMark: View {
    var body: some View {
        Group {
            if let logo = Self.logoImage {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.navy800)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.cream)
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.gold.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Theme.gold.opacity(0.14), radius: 8, y: 3)
    }

    private static let logoImage: NSImage? = {
        if let url = Bundle.main.url(forResource: "SadaaLogo", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = Bundle.main.url(forResource: "Sadaa", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let appIcon = NSApplication.shared.applicationIconImage, appIcon.isValid {
            return appIcon
        }
        return nil
    }()
}
