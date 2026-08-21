import AVFoundation

/// The speed ladder for read-aloud, and the rule for climbing it.
///
/// Tapping the read key while Timbre is already reading means "I have the
/// gist, go faster" — the podcast-scrubbing instinct. The ladder is
/// multipliers of the system's default rate rather than raw rate values,
/// because `AVSpeechUtteranceDefaultSpeechRate` is what the user's own
/// system voice settings have already been tuned around.
///
/// It stops at the top instead of wrapping. Wrapping would drop a listener
/// from double speed back to normal on an accidental tap, which is
/// disorienting in a way that "already at maximum" never is.
nonisolated enum ReadingSpeed {

    /// Multipliers applied to the system default rate.
    static let ladder: [Float] = [1.0, 1.25, 1.5, 2.0]

    static var slowest: Float { ladder[0] }

    /// The next rung up, or the same rung if already at the top.
    static func next(after multiplier: Float) -> Float {
        ladder.first { $0 > multiplier + 0.001 } ?? ladder[ladder.count - 1]
    }

    static func isFastest(_ multiplier: Float) -> Bool {
        multiplier >= ladder[ladder.count - 1] - 0.001
    }

    /// The utterance rate for a multiplier, clamped to what AVFoundation
    /// accepts — beyond the maximum the synthesizer clips silently, which
    /// would make a tap look like it did nothing.
    static func utteranceRate(for multiplier: Float) -> Float {
        min(AVSpeechUtteranceDefaultSpeechRate * multiplier, AVSpeechUtteranceMaximumSpeechRate)
    }

    /// Label for the overlay: "1×", "1.25×", "2×".
    static func label(for multiplier: Float) -> String {
        let rounded = (multiplier * 100).rounded() / 100
        let text =
            rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%g", rounded)
        return "\(text)×"
    }
}
