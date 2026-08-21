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

        /// Virtual key codes from `Carbon/Events.h` (`kVK_ANSI_C`/`_V`).
        /// These are physical positions, not characters, so they are correct
        /// on non-QWERTY layouts too.
        var code: CGKeyCode {
            switch self {
            case .c: 8
            case .v: 9
            }
        }
    }

    /// Presses ⌘ plus `key`.
    static func press(_ key: Key) {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Don't let our synthetic keystroke be seen by our own event taps.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key.code, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key.code, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
