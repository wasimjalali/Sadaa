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
        // 1. Clipboard backup, always.
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 2. Try Accessibility insertion at the caret.
        if axInsert(text) { return .insertedViaAX }

        // 3. Fall back to synthetic Cmd-V (clipboard already holds the text).
        if synthesizePaste() { return .pasted }

        return .clipboardOnly
    }

    private func axInsert(_ text: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusErr = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef)
        guard focusErr == .success, let focusedRef else { return false }
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
