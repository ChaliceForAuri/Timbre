import AVFoundation
import Testing

@testable import TimbreKit

@Suite("ReadingSpeed")
struct ReadingSpeedTests {

    @Test("Each tap climbs one rung")
    func climbsLadder() {
        var speed = ReadingSpeed.slowest
        var seen = [speed]
        for _ in 0..<3 {
            speed = ReadingSpeed.next(after: speed)
            seen.append(speed)
        }
        #expect(seen == [1.0, 1.25, 1.5, 2.0])
    }

    /// Wrapping would drop a listener from double speed to normal on a
    /// stray tap — disorienting in a way that "already at max" is not.
    @Test("The top rung holds instead of wrapping")
    func stopsAtTop() {
        #expect(ReadingSpeed.next(after: 2.0) == 2.0)
        #expect(ReadingSpeed.isFastest(2.0))
        #expect(!ReadingSpeed.isFastest(1.5))
    }

    /// AVFoundation clips silently past its maximum, which would make a tap
    /// look like it did nothing.
    @Test("Rates never exceed what AVFoundation accepts")
    func clampsToMaximum() {
        for multiplier in ReadingSpeed.ladder {
            #expect(ReadingSpeed.utteranceRate(for: multiplier) <= AVSpeechUtteranceMaximumSpeechRate)
        }
    }

    @Test("Labels read as speeds, not floats")
    func labels() {
        #expect(ReadingSpeed.label(for: 1.0) == "1×")
        #expect(ReadingSpeed.label(for: 1.25) == "1.25×")
        #expect(ReadingSpeed.label(for: 2.0) == "2×")
    }
}
