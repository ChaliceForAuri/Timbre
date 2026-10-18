import AppKit

/// Posts a command-modified keystroke as if the user typed it.
///
/// Timbre uses the pasteboard in both directions — ⌘V to insert dictated
/// text, ⌘C to grab a selection to read aloud — so the mechanism lives in
/// one place. Requires Accessibility permission; without it the events are
/// silently discarded by the window server.
nonisolated enum SyntheticKey {

    enum Key {
        case c
        case v
        case leftArrow
        case rightArrow

        /// Virtual key codes from `Carbon/Events.h` (`kVK_ANSI_C`/`_V`,
        /// `kVK_LeftArrow`/`_RightArrow`). These are physical positions, not
        /// characters, so they are correct on non-QWERTY layouts too.
        var code: CGKeyCode {
            switch self {
            case .c: 8
            case .v: 9
            case .leftArrow: 123
            case .rightArrow: 124
            }
        }
    }

    /// Presses ⌘ plus `key`.
    static func press(_ key: Key) {
        press(key, modifiers: .maskCommand)
    }

    /// Presses `key` with `modifiers`, `times` over — shift-left to grow a
    /// selection backwards one character at a time, for fields that will
    /// not take a selection any other way (GDR-0018).
    static func press(_ key: Key, modifiers: CGEventFlags, times: Int = 1) {
        guard times > 0 else { return }
        let source = CGEventSource(stateID: .combinedSessionState)

        // Don't let our synthetic keystroke be seen by our own event taps.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        for _ in 0..<times {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key.code, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key.code, keyDown: false)
            keyDown?.flags = modifiers
            keyUp?.flags = modifiers
            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
