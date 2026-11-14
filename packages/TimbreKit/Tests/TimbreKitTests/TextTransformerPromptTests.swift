import Testing

@testable import TimbreKit

struct TextTransformerPromptTests {

    @Test func everyCommandCarriesTheSelectionAndItsOwnInstructions() {
        var seen: Set<String> = []
        for command in VoiceCommand.allCases {
            #expect(TextTransformer.makePrompt(for: command, text: "teh text").contains("teh text"))
            seen.insert(TextTransformer.instructions(for: command))
        }
        // Learn saves, then explains: it has no instructions of its own (GDR-0033).
        #expect(seen.count == VoiceCommand.allCases.count - 1)
        #expect(TextTransformer.instructions(for: .learn) == TextTransformer.instructions(for: .explain))
    }

    /// The two rules that make each command safe to point at someone's text.
    @Test func instructionsStateTheirGuardrails() {
        #expect(TextTransformer.instructions(for: .fix).contains("comes back unchanged"))
        #expect(TextTransformer.instructions(for: .explain).contains("not sure"))
    }

    /// Every part of this shape was measured: fenced, instruction after the
    /// text, a word budget, and what must survive it.
    @Test func theShortenPromptFencesTheTextAndStatesABudgetAfterIt() {
        let prompt = TextTransformer.makePrompt(
            for: .shorten, text: "one two three four five six seven eight nine ten")
        #expect(prompt.contains("It has 10 words; use no more than 5."))
        #expect(prompt.contains("every request"))

        let fence = prompt.range(of: "one two three")!.lowerBound
        let instruction = prompt.range(of: "Rewrite the text above")!.lowerBound
        #expect(fence < instruction)
    }
}
