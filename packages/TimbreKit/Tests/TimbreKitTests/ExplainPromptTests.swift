import Testing

@testable import TimbreKit

struct ExplainPromptTests {

    /// Explain answers from what the user taught before the model guesses
    /// (GDR-0012); the prompt says what it knows.
    @Test func groundsTheExplainPromptInWhatWasTaught() {
        let taught = Acronym(term: "ADR", meaning: "Architecture Decision Record")!
        let prompt = TextTransformer.makePrompt(for: .explain, text: "Write an ADR.", known: [taught])
        #expect(prompt.contains("ADR means Architecture Decision Record"))
        #expect(!TextTransformer.makePrompt(for: .explain, text: "Write an ADR.").contains("dictionary"))
    }
}
