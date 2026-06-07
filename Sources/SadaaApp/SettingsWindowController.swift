import AppKit
import SwiftUI
import SadaaCore

final class SettingsWindowController {
    private var window: NSWindow?

    func show(settings: AppSettings) {
        if window == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(settings: settings))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Sadaa Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            self.window = window
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
