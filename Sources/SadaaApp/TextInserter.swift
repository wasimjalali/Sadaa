import AppKit
import ApplicationServices
import Carbon.HIToolbox

enum DeliveryOutcome {
    case insertedViaAX   // typed into the focused element
    case pasted          // synthetic Cmd-V (text was on the clipboard)
    case clipboardOnly   // both failed; user pastes manually
}

/// Delivers final text: paste at the cursor, AX insert as a fallback, and the
/// clipboard as the last-resort backup. The user's own clipboard is preserved
/// across delivery (snapshot + restore). Spec sections 4 and 5.
struct TextInserter {
    /// How long to wait before putting the user's clipboard back, so the target
    /// app has consumed the synthetic paste first. A synthetic Cmd-V is usually
    /// consumed within tens of ms; this is a comfortable margin.
    private let restoreDelay: TimeInterval = 0.25

    @discardableResult
    func deliver(_ text: String) -> DeliveryOutcome {
        let pasteboard = NSPasteboard.general

        // A secure field became active between record and delivery: never type or
        // paste into a password box. Leave the text on the clipboard so the user
        // can paste it somewhere safe themselves. Spec section 5.
        if IsSecureEventInputEnabled() {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return .clipboardOnly
        }

        // Snapshot so the user's clipboard can be restored after delivery.
        let saved = Clipboard.snapshot(pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 1. Synthetic Cmd-V FIRST. Paste routes through each app's normal paste
        // handling, so it lands in terminals, Electron and web fields. Writing
        // kAXSelectedText is unreliable there: Terminal, for one, reports
        // success but inserts nothing, which previously swallowed the text.
        if synthesizePaste() {
            restore(saved, after: restoreDelay)
            return .pasted
        }

        // 2. Fall back to direct AX insertion at the caret (e.g. when synthetic
        // events can't be posted). AX writes the element directly, not via the
        // clipboard, so the user's clipboard can go back right away.
        if axInsert(text) {
            restore(saved, after: 0)
            return .insertedViaAX
        }

        // 3. Both failed: keep the dictation on the clipboard as the backup and
        // let the HUD tell the user to paste it. Do NOT restore here.
        return .clipboardOnly
    }

    /// Restores the user's clipboard after `delay`. A zero delay still defers to
    /// the next runloop tick so an in-flight AX read has completed.
    private func restore(_ items: [NSPasteboardItem], after delay: TimeInterval) {
        guard !items.isEmpty else { return }
        if delay == 0 {
            DispatchQueue.main.async { Clipboard.restore(items) }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                Clipboard.restore(items)
            }
        }
    }

    private func axInsert(_ text: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusErr = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef)
        guard focusErr == .success, let focusedRef,
              CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else { return false }
        let element = focusedRef as! AXUIElement

        // Writing kAXSelectedText replaces the selection (or inserts at the
        // caret when there's no selection).
        let setErr = AXUIElementSetAttributeValue(
            element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        return setErr == .success
    }

    private func synthesizePaste() -> Bool {
        // Posting a synthetic keystroke needs Accessibility trust; an untrusted
        // process has its events silently dropped. Gate here so deliver() reports
        // .clipboardOnly (and the HUD shows the manual-paste hint) instead of
        // falsely claiming .pasted while nothing lands.
        guard AXIsProcessTrusted() else { return false }
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source,
                                    virtualKey: 9, keyDown: true),  // V
              let keyUp = CGEvent(keyboardEventSource: source,
                                  virtualKey: 9, keyDown: false)
        else { return false }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
