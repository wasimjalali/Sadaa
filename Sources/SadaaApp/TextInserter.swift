import AppKit
import ApplicationServices
import Carbon.HIToolbox

enum DeliveryOutcome {
    case insertedViaAX   // typed into the focused element
    case pasted          // synthetic Cmd-V (text was on the clipboard)
    case clipboardOnly   // both failed; user pastes manually
}

/// Watches whether anyone actually read our pasteboard item. The string is
/// provided lazily, so the provider callback firing is the one signal macOS
/// gives that the synthetic Cmd-V was consumed. Posting a Cmd-V proves
/// nothing: a window with no Edit-menu handling swallows it silently.
final class PasteSentinel: NSObject, NSPasteboardItemDataProvider {
    private let text: String
    private let lock = NSLock()
    private var read = false

    init(text: String) { self.text = text }

    var wasRead: Bool {
        lock.lock(); defer { lock.unlock() }
        return read
    }

    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem,
                    provideDataForType type: NSPasteboard.PasteboardType) {
        lock.lock(); read = true; lock.unlock()
        item.setString(text, forType: type)
    }
}

/// Delivers final text: paste at the cursor, AX insert as a fallback, and the
/// clipboard as the last-resort backup. The user's own clipboard is preserved
/// across delivery (snapshot + restore). Spec sections 4 and 5.
///
/// Delivery is verified, not assumed: the text goes on the clipboard as a lazy
/// item (PasteSentinel), and only a target app actually reading it counts as a
/// paste. An unconsumed Cmd-V used to be reported as success, after which the
/// clipboard restore wiped the dictation; now it falls through to AX insertion
/// and finally to leaving the text on the clipboard with the manual-paste hint.
struct TextInserter {
    /// First consumption check. A synthetic Cmd-V is usually consumed within
    /// tens of ms; this is a comfortable margin.
    private let firstCheck: TimeInterval = 0.25
    /// Last-chance check for slow consumers (Electron apps under load).
    private let finalCheck: TimeInterval = 0.6

    func deliver(_ text: String,
                 completion: @escaping (DeliveryOutcome) -> Void = { _ in }) {
        let pasteboard = NSPasteboard.general

        // A secure field became active between record and delivery: never type or
        // paste into a password box. Leave the text on the clipboard so the user
        // can paste it somewhere safe themselves. Spec section 5.
        if IsSecureEventInputEnabled() {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            completion(.clipboardOnly)
            return
        }

        // Snapshot so the user's clipboard can be restored after delivery.
        let saved = Clipboard.snapshot(pasteboard)
        let sentinel = PasteSentinel(text: text)
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setDataProvider(sentinel, forTypes: [.string])
        // Concrete marker type so Clipboard.snapshot never treats this item as
        // the user's clipboard or force-resolves the promise above.
        item.setString("1", forType: Clipboard.deliveryMarker)
        pasteboard.writeObjects([item])
        let ourChangeCount = pasteboard.changeCount

        // Note: a clipboard manager polling the pasteboard also resolves the
        // promise, which reads as consumption; delivery then degrades to the
        // legacy paste-and-restore behavior, no worse than before.

        // 1. Synthetic Cmd-V FIRST. Paste routes through each app's normal paste
        // handling, so it lands in terminals, Electron and web fields. Writing
        // kAXSelectedText is unreliable there: Terminal, for one, reports
        // success but inserts nothing, which previously swallowed the text.
        guard synthesizePaste() else {
            fallBack(text: text, saved: saved, pasteboard: pasteboard,
                     ourChangeCount: ourChangeCount, completion: completion)
            return
        }

        // The checks are scheduled, never blocking: the provider callback needs
        // this process responsive while the target app reads the promised string.
        DispatchQueue.main.asyncAfter(deadline: .now() + firstCheck) {
            if sentinel.wasRead {
                Self.restoreIfUnchanged(saved, to: pasteboard,
                                        expectedChangeCount: ourChangeCount)
                completion(.pasted)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (finalCheck - firstCheck)) {
                if sentinel.wasRead {
                    Self.restoreIfUnchanged(saved, to: pasteboard,
                                            expectedChangeCount: ourChangeCount)
                    completion(.pasted)
                } else {
                    // Nobody consumed the paste (e.g. a field that ignores
                    // Cmd-V). Don't restore, or the dictation would be wiped.
                    fallBack(text: text, saved: saved, pasteboard: pasteboard,
                             ourChangeCount: ourChangeCount, completion: completion)
                }
            }
        }
    }

    /// 2. Direct AX insertion at the caret (e.g. when synthetic events can't be
    /// posted, or the paste was never consumed). AX writes the element directly,
    /// not via the clipboard, so the user's clipboard can go back right away.
    /// 3. Both failed: keep the dictation on the clipboard as the backup and
    /// let the HUD tell the user to paste it.
    private func fallBack(text: String, saved: [NSPasteboardItem],
                          pasteboard: NSPasteboard, ourChangeCount: Int,
                          completion: (DeliveryOutcome) -> Void) {
        // Re-check secure input: this runs up to 0.6s after deliver() started,
        // and a password field may have grabbed focus since. Never AX-write
        // into it.
        if !IsSecureEventInputEnabled(), axInsert(text) {
            Self.restoreIfUnchanged(saved, to: pasteboard,
                                    expectedChangeCount: ourChangeCount)
            completion(.insertedViaAX)
            return
        }
        // Make the clipboard backup concrete so it no longer depends on the
        // lazy provider, but only while the clipboard is still ours; if the
        // user copied something newer in the meantime, theirs wins.
        if pasteboard.changeCount == ourChangeCount {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
        completion(.clipboardOnly)
    }

    /// Restores the user's clipboard, unless something else was copied since we
    /// wrote ours; clobbering a newer copy would lose the user's data.
    private static func restoreIfUnchanged(_ items: [NSPasteboardItem],
                                           to pasteboard: NSPasteboard,
                                           expectedChangeCount: Int) {
        guard !items.isEmpty else { return }
        guard pasteboard.changeCount == expectedChangeCount else { return }
        Clipboard.restore(items, to: pasteboard)
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
        // process has its events silently dropped. Gate here so deliver() falls
        // back (and the HUD shows the manual-paste hint) instead of waiting on
        // a paste that can never land.
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
