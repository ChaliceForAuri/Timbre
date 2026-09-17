/// Something one of Timbre's three hotkeys did.
///
/// Dictation is a hold gesture, so it reports press and release. Reading is
/// tap-based and command mode arms after a delay, so those report the raw key
/// transitions and let the controller — where async timing is natural —
/// decide what they meant. That division is deliberate: ADR-0007 requires
/// the event path itself stay trivial and free of the concurrency runtime.
nonisolated enum HotkeyEvent: Sendable {
    /// Right Option, held to dictate.
    case pressed
    case released
    /// Left Option, tapped to read aloud.
    case readKeyDown
    case readKeyUp
    /// Right Command, held over a selection for command mode (GDR-0012).
    case commandKeyDown
    case commandKeyUp
    /// Something else happened while right Command was down — another
    /// modifier moved, a key was typed, the mouse was clicked — so the hold
    /// is an ordinary shortcut, not a command.
    case commandInterrupted
}

/// Pure transition detection for Timbre's modifier hotkeys.
///
/// `.flagsChanged` events say a modifier moved but not which direction, and
/// `NSEvent.ModifierFlags.option` can't tell left from right — holding left
/// Option while tapping right would desynchronize a naive check. The
/// device-dependent flag bit disambiguates: it's set exactly while that
/// physical key is down.
nonisolated struct HoldDetector {

    /// Right Option's key code — the dictation key.
    static let rightOptionKeyCode: UInt16 = 61

    /// Left Option's key code — the read-aloud key. Right hand talks, left
    /// hand listens.
    static let leftOptionKeyCode: UInt16 = 58

    /// Right Command's key code — the command-mode key.
    static let rightCommandKeyCode: UInt16 = 54

    /// `NX_DEVICERALTKEYMASK` from IOKit — the right-Option device bit within
    /// `NSEvent.modifierFlags`. Not exposed as a named constant in AppKit.
    static let rightOptionFlagMask: UInt = 0x40

    /// `NX_DEVICELALTKEYMASK` — the matching bit for left Option.
    static let leftOptionFlagMask: UInt = 0x20

    /// `NX_DEVICERCMDKEYMASK` — the matching bit for right Command.
    static let rightCommandFlagMask: UInt = 0x10

    private(set) var isHeld = false
    private(set) var isReadKeyDown = false
    private(set) var isCommandKeyDown = false

    /// Feed a `.flagsChanged` event's key code and raw modifier flags;
    /// returns an event exactly when a key's state changes.
    mutating func transition(keyCode: UInt16, rawModifierFlags: UInt) -> HotkeyEvent? {
        switch keyCode {
        case Self.rightOptionKeyCode:
            let isDown = rawModifierFlags & Self.rightOptionFlagMask != 0
            switch (isDown, isHeld) {
            case (true, false):
                isHeld = true
                return .pressed
            case (false, true):
                isHeld = false
                return .released
            default:
                return nil
            }

        case Self.leftOptionKeyCode:
            let isDown = rawModifierFlags & Self.leftOptionFlagMask != 0
            switch (isDown, isReadKeyDown) {
            case (true, false):
                isReadKeyDown = true
                return .readKeyDown
            case (false, true):
                isReadKeyDown = false
                return .readKeyUp
            default:
                return nil
            }

        case Self.rightCommandKeyCode:
            let isDown = rawModifierFlags & Self.rightCommandFlagMask != 0
            switch (isDown, isCommandKeyDown) {
            case (true, false):
                isCommandKeyDown = true
                return .commandKeyDown
            case (false, true):
                isCommandKeyDown = false
                return .commandKeyUp
            default:
                return nil
            }

        default:
            // Any other modifier moving while right Command is down — Shift
            // for ⌘⇧4, left Command, Control — makes the hold a shortcut.
            return isCommandKeyDown ? .commandInterrupted : nil
        }
    }
}
