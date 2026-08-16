/// A press or release of the dictation hotkey.
nonisolated enum HotkeyEvent: Sendable {
    case pressed
    case released
}

/// Pure press/release detection for the right Option key.
///
/// `.flagsChanged` events say a modifier moved but not which direction, and
/// `NSEvent.ModifierFlags.option` can't tell left from right — holding left
/// Option while tapping right would desynchronize a naive check. The
/// device-dependent flag bit disambiguates: it's set exactly while the right
/// Option key itself is down.
nonisolated struct HoldDetector {

    /// Right Option's key code. (Left Option is 58, right Command is 54.)
    static let rightOptionKeyCode: UInt16 = 61

    /// `NX_DEVICERALTKEYMASK` from IOKit — the right-Option device bit within
    /// `NSEvent.modifierFlags`. Not exposed as a named constant in AppKit.
    static let rightOptionFlagMask: UInt = 0x40

    private(set) var isHeld = false

    /// Feed a `.flagsChanged` event's key code and raw modifier flags;
    /// returns an event exactly when the hold state changes.
    mutating func transition(keyCode: UInt16, rawModifierFlags: UInt) -> HotkeyEvent? {
        guard keyCode == Self.rightOptionKeyCode else { return nil }

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
    }
}
