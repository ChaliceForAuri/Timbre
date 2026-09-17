import Testing

@testable import TimbreKit

struct HoldDetectorTests {

    private static let rightOption = HoldDetector.rightOptionKeyCode
    private static let rightOptionBit = HoldDetector.rightOptionFlagMask
    /// `NSEvent.ModifierFlags.option` — the direction-blind bit that is set
    /// for either Option key.
    private static let genericOptionBit: UInt = 0x8_0000
    /// `NX_DEVICELALTKEYMASK` — the left Option device bit.
    private static let leftOptionBit: UInt = 0x20
    private static let leftOptionKeyCode: UInt16 = 58

    @Test func pressThenRelease() {
        var detector = HoldDetector()
        let press = detector.transition(
            keyCode: Self.rightOption,
            rawModifierFlags: Self.genericOptionBit | Self.rightOptionBit
        )
        #expect(press == .pressed)

        let release = detector.transition(keyCode: Self.rightOption, rawModifierFlags: 0)
        #expect(release == .released)
    }

    /// Left Option now drives read-aloud, so it reports its own event —
    /// but it must never move the *dictation* hold state.
    @Test func leftOptionDoesNotStartDictation() {
        var detector = HoldDetector()
        let event = detector.transition(
            keyCode: Self.leftOptionKeyCode,
            rawModifierFlags: Self.genericOptionBit | Self.leftOptionBit
        )
        #expect(event == .readKeyDown)
        #expect(!detector.isHeld)
    }

    @Test func ignoresUnrelatedKeys() {
        var detector = HoldDetector()
        // Left Shift (56) — not a hotkey, and nothing is held.
        #expect(detector.transition(keyCode: 56, rawModifierFlags: 0x2) == nil)
        #expect(!detector.isHeld)
        #expect(!detector.isReadKeyDown)
    }

    /// The regression this type exists to prevent: holding left Option while
    /// tapping right must still detect the right-Option release, even though
    /// the generic `.option` bit stays set the whole time.
    @Test func leftOptionHeldDoesNotMaskRightOptionRelease() {
        var detector = HoldDetector()

        // Right Option down while left Option is already held.
        let press = detector.transition(
            keyCode: Self.rightOption,
            rawModifierFlags: Self.genericOptionBit | Self.leftOptionBit | Self.rightOptionBit
        )
        #expect(press == .pressed)

        // Right Option up; left Option still held, so `.option` is still set.
        let release = detector.transition(
            keyCode: Self.rightOption,
            rawModifierFlags: Self.genericOptionBit | Self.leftOptionBit
        )
        #expect(release == .released)
    }

    @Test func repeatedFlagsChangesDoNotDoubleFire() {
        var detector = HoldDetector()
        let flags = Self.genericOptionBit | Self.rightOptionBit
        #expect(detector.transition(keyCode: Self.rightOption, rawModifierFlags: flags) == .pressed)
        #expect(detector.transition(keyCode: Self.rightOption, rawModifierFlags: flags) == nil)
    }

    @Test func releaseWithoutPressIsIgnored() {
        var detector = HoldDetector()
        let event = detector.transition(keyCode: Self.rightOption, rawModifierFlags: 0)
        #expect(event == nil)
    }

    /// Left Option is the read-aloud key; the two must not interfere, which
    /// is exactly what a flags-only check would get wrong.
    @Test("Left Option reports its own transitions")
    func detectsLeftOption() {
        var detector = HoldDetector()
        let left = HoldDetector.leftOptionKeyCode
        #expect(
            detector.transition(keyCode: left, rawModifierFlags: HoldDetector.leftOptionFlagMask)
                == .readKeyDown
        )
        #expect(detector.transition(keyCode: left, rawModifierFlags: 0) == .readKeyUp)
    }

    @Test("Holding one Option key doesn't disturb the other")
    func keysAreIndependent() {
        var detector = HoldDetector()
        let left = HoldDetector.leftOptionFlagMask
        let right = HoldDetector.rightOptionFlagMask

        #expect(
            detector.transition(keyCode: HoldDetector.leftOptionKeyCode, rawModifierFlags: left)
                == .readKeyDown
        )
        // Right Option goes down while left is still held: both bits set.
        #expect(
            detector.transition(
                keyCode: HoldDetector.rightOptionKeyCode,
                rawModifierFlags: left | right
            ) == .pressed
        )
        // Right releases; left is still down and must stay down.
        #expect(
            detector.transition(
                keyCode: HoldDetector.rightOptionKeyCode,
                rawModifierFlags: left
            ) == .released
        )
        #expect(detector.isReadKeyDown)
    }

    // MARK: - Right Command (command mode)

    private static let rightCommand = HoldDetector.rightCommandKeyCode
    private static let rightCommandBit = HoldDetector.rightCommandFlagMask
    private static let genericCommandBit: UInt = 0x10_0000

    @Test func rightCommandReportsDownAndUp() {
        var detector = HoldDetector()
        let down = detector.transition(
            keyCode: Self.rightCommand,
            rawModifierFlags: Self.genericCommandBit | Self.rightCommandBit
        )
        #expect(down == .commandKeyDown)
        #expect(!detector.isHeld)

        #expect(detector.transition(keyCode: Self.rightCommand, rawModifierFlags: 0) == .commandKeyUp)
    }

    /// ⌘⇧4, ⌘⌃Space: another modifier moving while right ⌘ is down makes
    /// the hold a shortcut, not a command.
    @Test func anotherModifierDuringACommandHoldInterruptsIt() {
        var detector = HoldDetector()
        _ = detector.transition(
            keyCode: Self.rightCommand,
            rawModifierFlags: Self.genericCommandBit | Self.rightCommandBit
        )
        let shift = detector.transition(
            keyCode: 56,
            rawModifierFlags: Self.genericCommandBit | Self.rightCommandBit | 0x2
        )
        #expect(shift == .commandInterrupted)
    }

    /// Left ⌘ is the everyday shortcut key and must never arm command mode.
    @Test func leftCommandIsNotTheCommandKey() {
        var detector = HoldDetector()
        #expect(detector.transition(keyCode: 55, rawModifierFlags: Self.genericCommandBit | 0x8) == nil)
        #expect(!detector.isCommandKeyDown)
    }
}
