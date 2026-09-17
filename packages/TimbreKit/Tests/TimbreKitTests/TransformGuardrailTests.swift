import Testing

@testable import TimbreKit

struct TransformGuardrailTests {

    private let paragraph = String(repeating: "The release is delayed until Friday. ", count: 6)

    @Test func aFixMovesAFewCharacters() {
        #expect(TransformGuardrail.accepts("you are", for: .fix, original: "u r"))
        #expect(
            TransformGuardrail.accepts(
                "I believe it's on Wednesday.", for: .fix, original: "i beleive its on wendesday"))
    }

    @Test func aFixThatRewritesOrRefusesIsRejected() {
        #expect(!TransformGuardrail.accepts("Delayed.", for: .fix, original: paragraph))
        #expect(!TransformGuardrail.accepts(paragraph + paragraph, for: .fix, original: paragraph))
        #expect(!TransformGuardrail.accepts("   ", for: .fix, original: paragraph))
    }

    @Test func shortenMustActuallyBeShorterButStillTheText() {
        #expect(
            TransformGuardrail.accepts(
                "The release is delayed until Friday.", for: .shorten, original: paragraph))
        #expect(!TransformGuardrail.accepts(paragraph, for: .shorten, original: paragraph))
        #expect(!TransformGuardrail.accepts("Delayed.", for: .shorten, original: paragraph))
    }

    /// Measured: asked to explain "API", the model sometimes answers "API".
    @Test func anEchoIsNotAnExplanation() {
        #expect(TransformGuardrail.accepts("Architecture Decision Record.", for: .explain, original: "ADR"))
        #expect(!TransformGuardrail.accepts("API", for: .explain, original: "API"))
        #expect(!TransformGuardrail.accepts("api.", for: .explain, original: " API "))
    }

    @Test func trimmingWhitespaceIsNotAShortening() {
        #expect(
            !TransformGuardrail.accepts("Same length text", for: .shorten, original: "Same length text  "))
    }

    @Test func aCopyIsNoReductionRatherThanAFailure() {
        #expect(TransformGuardrail.isNoReduction(paragraph, original: paragraph))
        #expect(
            !TransformGuardrail.isNoReduction("The release is delayed until Friday.", original: paragraph))
        #expect(!TransformGuardrail.isNoReduction("", original: paragraph))
    }
}
