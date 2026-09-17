import Testing

@testable import TimbreKit

struct DoubledWordsTests {

    @Test func collapsesADoubledFunctionWordKeepingTheFirstAsWritten() {
        #expect(DoubledWords.collapsed("and the the client agreed") == "and the client agreed")
        #expect(DoubledWords.collapsed("The the build is green") == "The build is green")
        #expect(DoubledWords.collapsed("go to to  to the shop") == "go to the shop")
    }

    /// Real English doubles. Collapsing these would be a rewrite.
    @Test func leavesLegitimateDoublesAlone() {
        for sentence in [
            "She had had enough.", "I know that that is true.", "It was very very good.", "No no, not that.",
        ] {
            #expect(DoubledWords.collapsed(sentence) == sentence)
        }
    }

    @Test func doesNotMatchAcrossWordBoundaries() {
        #expect(DoubledWords.collapsed("a apple at atlas") == "a apple at atlas")
        #expect(DoubledWords.collapsed("into to") == "into to")
    }
}
