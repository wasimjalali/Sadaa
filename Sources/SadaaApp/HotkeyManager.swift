import AppKit
import SadaaCore

/// System-wide key listener via CGEventTap.
/// - Right Option tap -> onToggle
/// - Esc while recording -> onCancel (the Esc event is consumed)
/// Requires Accessibility trust. Spec sections 4 and 8.
final class HotkeyManager {
    private static let rightOptionKeycode: Int64 = 61
    private static let escapeKeycode: Int64 = 53

    var onToggle: (() -> Void)?
    var onCancel: (() -> Void)?
    /// The app layer tells us whether a recording is active so we know
    /// when Esc belongs to us.
    var isRecordingActive: (() -> Bool) = { false }

    private var recognizer = RightOptionTapRecognizer()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    enum HotkeyError: Error { case tapCreationFailed }

    func start() throws {
        let mask = (1 << CGEventType.flagsChanged.rawValue)
                 | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                let manager = Unmanaged<HotkeyManager>
                    .fromOpaque(refcon!).takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { throw HotkeyError.tapCreationFailed }

        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType,
                        event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables taps that stall; re-enable and move on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let now = ProcessInfo.processInfo.systemUptime

        switch type {
        case .flagsChanged where keycode == Self.rightOptionKeycode:
            // .maskAlternate is set when EITHER option key is down. We rely on
            // having already filtered to keycode 61, so this means right option.
            // Edge case not handled (MVP): if left option is also held, the up
            // event for right option still shows maskAlternate set, so the tap
            // won't register. Acceptable for now.
            let isDown = event.flags.contains(.maskAlternate)
            let fired = recognizer.handle(isDown ? .rightOptionDown(at: now)
                                                 : .rightOptionUp(at: now))
            if fired {
                DispatchQueue.main.async { [weak self] in self?.onToggle?() }
            }
        case .keyDown where keycode == Self.escapeKeycode:
            if isRecordingActive() {
                DispatchQueue.main.async { [weak self] in self?.onCancel?() }
                return nil // consume Esc so the frontmost app never sees it
            }
        case .keyDown:
            _ = recognizer.handle(.otherKeyDown)
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }
}
