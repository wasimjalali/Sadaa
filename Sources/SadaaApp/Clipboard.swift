import AppKit

/// Save and restore the user's clipboard around a synthetic paste or copy.
///
/// Dictation and voice-edit both have to put their own text on the clipboard to
/// drive Cmd-V. Wispr Flow and good dictation tools never leave the user's
/// clipboard clobbered, so we snapshot it first and put it back once the paste
/// has landed. Promised/lazy types (file promises and the like) can't be copied
/// out and are dropped on restore; the common types (text, RTF, images, URLs)
/// round-trip fine.
enum Clipboard {
    /// Deep-copy the current items so they survive a `clearContents()`.
    static func snapshot(_ pasteboard: NSPasteboard = .general) -> [NSPasteboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    /// Put a snapshot back. A no-op for an empty snapshot, which leaves whatever
    /// is currently on the clipboard in place (used as the never-lose backup).
    static func restore(_ items: [NSPasteboardItem],
                        to pasteboard: NSPasteboard = .general) {
        guard !items.isEmpty else { return }
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }
}
