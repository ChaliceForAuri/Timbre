import Testing

@testable import TimbreKit

struct PolishGuardrailTests {

    private let raw = "so um I think we should probably ship the feature on Tuesday you know"

    @Test func acceptsAReasonableCleanup() {
        let cleaned = "I think we should ship the feature on Tuesday."
        #expect(PolishGuardrail.accepts(cleaned: cleaned, raw: raw))
    }

    @Test func rejectsEmptyOutput() {
        #expect(!PolishGuardrail.accepts(cleaned: "", raw: raw))
    }

    @Test func rejectsAggressiveSummarization() {
        // The classic small-model failure: three sentences become one word.
        #expect(!PolishGuardrail.accepts(cleaned: "Ship Tuesday.", raw: raw))
    }

    @Test func rejectsRunawayExpansion() {
        let expanded = String(repeating: "The model has added a great deal of explanation. ", count: 10)
        #expect(!PolishGuardrail.accepts(cleaned: expanded, raw: raw))
    }

    @Test func acceptsWhenRawIsEmptyButCleanedIsShort() {
        // Degenerate input shouldn't crash the ratio math (division guard).
        #expect(PolishGuardrail.accepts(cleaned: "a", raw: ""))
    }
}
