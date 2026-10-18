/// When a dictation should give up on the default microphone and use the
/// Mac's own (ADR-0012). Pure, so the rule is a test rather than a feeling.
///
/// A Bluetooth headset that another device is streaming to stays listed as
/// the Mac's input and delivers exact digital zeros for as long as the key
/// is held. A headset that is merely waking delivers zeros too — but for
/// well under two seconds on every Mac measured so far (issue #4). So the
/// rule waits long enough to tell the two apart, and never fires for a
/// wired or built-in input, which cannot be silent in that way.
nonisolated enum InputFallback {

    /// How long a Bluetooth input may stay perfectly silent before Timbre
    /// switches to the built-in microphone for the rest of the dictation.
    static let silence: Duration = .milliseconds(2500)

    static func shouldFallBack(inputIsBluetooth: Bool, heardAudio: Bool, after elapsed: Duration) -> Bool {
        inputIsBluetooth && !heardAudio && elapsed >= silence
    }
}
