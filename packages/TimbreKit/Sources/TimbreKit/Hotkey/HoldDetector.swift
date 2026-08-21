/// Something one of Timbre's two hotkeys did.
///
/// Dictation is a hold gesture, so it reports press and release. Reading is
/// tap-based, so this reports the raw key transitions and lets the
/// controller — where async timing is natural — decide tap from hold. That
/// division is deliberate: ADR-0007 requires the event path itself stay
/// trivial and free of the concurrency runtime.
nonisolated enum HotkeyEvent: Sendable {
    /// Right Option, held to dictate.
    case pressed
    case released
    /// Left Option, tapped to read aloud.
    case readKeyDown
    case readKeyUp
}

/// Pure transition detection for both Option keys.
///
/// `.flagsChanged` events say a modifier moved but not which direction, and
/// `NSEvent.ModifierFlags.option` can't tell left from right — holding left
/// Option while tapping right would desynchronize a naive check. The
/// device-dependent flag bit disambiguates: it's set exactly while the right
/// Option key itself is down.
nonisolated struct HoldDetector {

    /// Right Option's key code. (Left Option is 58, right Command is 54.)
    static let rightOptionKeyCode: UInt16 = 61

    /// Left Option's key code — the read-aloud key. Right hand talks, left
    /// hand listens.
    static let leftOptionKeyCode: UInt16 = 58

    /// `NX_DEVICERALTKEYMASK` from IOKit — the right-Option device bit within
    /// `NSEvent.modifierFlags`. Not exposed as a named constant in AppKit.
    static let rightOptionFlagMask: UInt = 0x40

    /// `NX_DEVICELALTKEYMASK` — the matching bit for left Option.
    static let leftOptionFlagMask: UInt = 0x20

    private(set) var isHeld = false
    private(set) var isReadKeyDown = false

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

        default:
            return nil
        }
    }
}
