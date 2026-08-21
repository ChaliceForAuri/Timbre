import Testing

@testable import TimbreKit

struct TranscriptAccumulatorTests {

    @Test func startsEmpty() {
        let accumulator = TranscriptAccumulator()
        #expect(accumulator.currentText.isEmpty)
    }

    @Test func volatileResultsReplaceEachOther() {
        var accumulator = TranscriptAccumulator()
        accumulator.apply("hel", isFinal: false)
        accumulator.apply("hello wor", isFinal: false)
        accumulator.apply("hello world", isFinal: false)
        #expect(accumulator.currentText == "hello world")
    }

    @Test func finalizedResultsAccumulate() {
        var accumulator = TranscriptAccumulator()
        accumulator.apply("Hello world. ", isFinal: true)
        accumulator.apply("Nice to meet you.", isFinal: true)
        #expect(accumulator.currentText == "Hello world. Nice to meet you.")
    }

    @Test func finalizationClearsTheVolatileGuess() {
        var accumulator = TranscriptAccumulator()
        accumulator.apply("hello wor", isFinal: false)
        accumulator.apply("Hello world.", isFinal: true)
        #expect(accumulator.currentText == "Hello world.")
    }

    @Test func mixedStreamKeepsFinalizedPrefixAndLatestGuess() {
        var accumulator = TranscriptAccumulator()
        accumulator.apply("Hello world. ", isFinal: true)
        accumulator.apply("nice to", isFinal: false)
        accumulator.apply("nice to meet", isFinal: false)
        #expect(accumulator.currentText == "Hello world. nice to meet")
    }

    @Test func trimsSurroundingWhitespace() {
        var accumulator = TranscriptAccumulator()
        accumulator.apply("  Hello world.  ", isFinal: true)
        #expect(accumulator.currentText == "Hello world.")
    }
}
