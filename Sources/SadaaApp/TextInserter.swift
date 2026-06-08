import AppKit
import ApplicationServices

enum DeliveryOutcome {
    case insertedViaAX   // typed into the focused element
    case pasted          // synthetic Cmd-V (text was on the clipboard)
    case clipboardOnly   // both failed; user pastes manually
}

/// Delivers final text: clipboard first (backup), then AX insert,
/// then Cmd-V fallback. Spec sections 4 and 5.
struct TextInserter {
    @discardableResult
    func deliver(_ text: String) -> DeliveryOutcome {
        // 1. Clipboard, always (also the backup the user can re-paste).
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 2. Synthetic Cmd-V FIRST. Paste routes through each app's normal paste
        // handling, so it lands in terminals, Electron and web fields. Writing
        // kAXSelectedText is unreliable there: Terminal, for one, reports
        // success but inserts nothing, which previously swallowed the text.
        if synthesizePaste() { return .pasted }

        // 3. Fall back to direct AX insertion at the caret (e.g. when synthetic
        // events can't be posted).
        if axInsert(text) { return .insertedViaAX }

        return .clipboardOnly
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
