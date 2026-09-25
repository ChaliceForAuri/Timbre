import AppKit

/// Types text into the focused app as keystrokes, without touching the
/// pasteboard — the mechanism behind words landing while the user is still
/// talking (GDR-0018).
///
/// Each event carries up to twenty UTF-16 units, the most a keyboard event
/// can hold; surrogate pairs are never split across two. The events carry
/// no modifier flags on purpose: the user is physically holding right ⌥
/// while these post, and an event stamped with that flag would reach the
/// app as ⌥-something rather than as text. Requires Accessibility, like
/// every synthetic event Timbre sends.
nonisolated enum SyntheticText {

    private static let unitsPerEvent = 20

    static func type(_ text: String) {
        guard !text.isEmpty else { return }

        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        for chunk in chunks(of: Array(text.utf16)) {
            guard
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else { return }
            var units = chunk
            keyDown.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            keyUp.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            keyDown.flags = []
            keyUp.flags = []
            keyDown.post(tap: .cgAnnotatedSessionEventTap)
            keyUp.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    /// Splits UTF-16 units into event-sized runs, keeping surrogate pairs whole.
    static func chunks(of units: [UInt16]) -> [[UInt16]] {
        var result: [[UInt16]] = []
        var index = 0
        while index < units.count {
            var end = min(index + unitsPerEvent, units.count)
            // A high surrogate at the boundary belongs with the unit after it.
            if end < units.count, UTF16.isLeadSurrogate(units[end - 1]) { end -= 1 }
            result.append(Array(units[index..<end]))
            index = end
        }
        return result
    }
}
