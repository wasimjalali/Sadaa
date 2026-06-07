import AppKit
import SwiftUI
import SadaaCore

/// Owns the single main app window. While the window is open the app is a
/// regular Dock app; when it closes, the app drops back to a menu-bar-only
/// accessory (the hotkey and status item keep working). The app does not quit.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(viewModel: SadaaViewModel, settings: AppSettings) {
        if window == nil {
            let hosting = NSHostingController(
                rootView: RootView(viewModel: viewModel, settings: settings))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Sadaa"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 900, height: 600))
            window.minSize = NSSize(width: 820, height: 560)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.setActivationPolicy(.regular)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Back to menu-bar-only. Window is kept (isReleasedWhenClosed=false) for reopen.
        NSApp.setActivationPolicy(.accessory)
    }
}
