import Foundation
import Testing

@testable import TimbreCore

struct SpellCheckTests {

    @Test func theCorpusHolds() throws {
        let outcomes = try SpellCorpus.load(from: Fixtures.url("spell.json")).run()
        #expect(outcomes.count >= 15)
        for outcome in outcomes {
            #expect(
                outcome.held,
                "\(outcome.id): heard \"\(outcome.verdict.heard)\" for \"\(outcome.verdict.expected)\", passed=\(outcome.verdict.passed)"
            )
        }
    }

    @Test func reportsWhatItHeard() {
        let verdict = SpellCheck.check("definitely", against: "definitely d e f i n a t e l y")
        #expect(verdict == SpellVerdict(passed: false, heard: "definately", expected: "definitely"))
    }

    @Test func tokensSplitOnPunctuationAndCase() {
        #expect(SpellCheck.tokens(of: "S-E-P. A,r;a:t!e?") == ["s", "e", "p", "a", "r", "a", "t", "e"])
    }

    @Test func neverPassesOnNothing() {
        #expect(!SpellCheck.check("word", against: "").passed)
        #expect(!SpellCheck.check("word", against: "word").passed)
    }
}
