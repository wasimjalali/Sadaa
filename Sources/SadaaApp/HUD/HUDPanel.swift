import AppKit
import SwiftUI

/// Borderless, non-activating floating panel at the bottom-center of the
/// active screen. Never steals focus from the app being dictated into.
final class HUDPanel {
    private var panel: NSPanel?
    private var hosting: NSHostingView<HUDView>?
    private var hideTimer: Timer?

    func show(_ display: HUDDisplay) {
        hideTimer?.invalidate()
        let view = HUDView(display: display)

        if let hosting {
            hosting.rootView = view
        } else {
            let hosting = NSHostingView(rootView: view)
            let panel = NSPanel(contentRect: .zero,
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.level = .statusBar
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces,
                                        .fullScreenAuxiliary]
            panel.contentView = hosting
            self.panel = panel
            self.hosting = hosting
        }

        guard let panel, let hosting else { return }
        hosting.layout()
        let size = hosting.fittingSize
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.visibleFrame
        panel.setFrame(NSRect(x: frame.midX - size.width / 2,
                              y: frame.minY + 100,
                              width: size.width, height: size.height),
                       display: true)
        panel.orderFrontRegardless()
    }

    /// Errors linger so they can be read; success states vanish quickly.
    func hide(after delay: TimeInterval = 0) {
        hideTimer?.invalidate()
        if delay == 0 {
            panel?.orderOut(nil)
            return
        }
        hideTimer = Timer.scheduledTimer(withTimeInterval: delay,
                                         repeats: false) { [weak self] _ in
            self?.panel?.orderOut(nil)
        }
    }
}
