import Foundation

/// Decides how much silence to put in front of speech so the audio route is
/// awake by the time words arrive.
///
/// A Bluetooth output route sleeps when idle, and the synthesizer starts
/// speaking the instant it is asked — so the opening words are rendered into
/// a route that isn't playing yet and are simply lost. It is the mirror of
/// the microphone warm-up in issue #4, on the output side.
///
/// The delay is adaptive rather than constant because the symptom is: cold
/// reads clip, warm reads don't. Charging every read a fixed pre-roll would
/// make the common case worse to fix the uncommon one.
nonisolated enum ReadingWarmup {

    /// How long a route stays awake after speech before it may sleep. Chosen
    /// to comfortably cover "tap again to speed up" and back-to-back reads.
    static let routeStaysWarm: Duration = .seconds(20)

    /// Silence prepended to a cold utterance. Long enough for a Bluetooth
    /// route to wake, short enough to read as responsiveness rather than lag.
    static let coldPreRoll: TimeInterval = 0.3

    /// Seconds of silence to prepend, given when speech last happened.
    static func preRoll(sinceLastSpeech elapsed: Duration?) -> TimeInterval {
        guard let elapsed else { return coldPreRoll }
        return elapsed > routeStaysWarm ? coldPreRoll : 0
    }
}
