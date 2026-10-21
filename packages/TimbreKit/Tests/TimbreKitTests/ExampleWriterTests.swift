import Testing

@testable import TimbreKit

struct ExampleWriterTests {

    @Test func thePromptCarriesTheWordTheMeaningAndTheField() {
        let prompt = ExampleWriter.makePrompt(term: "ephemeral", meaning: "short-lived", industry: "software")
        #expect(prompt.hasPrefix("Word: ephemeral\n"))
        #expect(prompt.contains("Meaning: short-lived"))
        #expect(prompt.contains("The reader works in software."))
        #expect(prompt.hasSuffix("Write the sentence."))
    }

    @Test func absentPartsAreLeftOut() {
        let prompt = ExampleWriter.makePrompt(term: "tacit", meaning: nil, industry: "")
        #expect(prompt == "Word: tacit\nWrite the sentence.")
    }
}
