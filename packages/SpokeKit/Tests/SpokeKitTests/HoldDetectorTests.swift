import Testing

@testable import SpokeKit

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

    @Test func ignoresOtherKeys() {
        var detector = HoldDetector()
        let event = detector.transition(
            keyCode: Self.leftOptionKeyCode,
            rawModifierFlags: Self.genericOptionBit | Self.leftOptionBit
        )
        #expect(event == nil)
        #expect(!detector.isHeld)
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
}
