import Testing

@testable import TimbreKit

struct ExplanationTrimmerTests {

    @Test func aShortAnswerIsLeftAlone() {
        let answer = "ADR stands for Architecture Decision Record. It captures one technical choice."
        #expect(ExplanationTrimmer.trimmed(answer) == answer)
    }

    @Test func keepsTheOpeningSentences() {
        let answer = "One. Two. Three. Four. Five."
        #expect(ExplanationTrimmer.trimmed(answer) == "One. Two. Three.")
    }

    @Test func staysWithinTheCardEvenWhenSentencesAreLong() {
        // Capitalised, because that is what a sentence is: the tokenizer
        // rightly refuses to split "word. word".
        let long = "Word " + String(repeating: "word ", count: 49).trimmingCharacters(in: .whitespaces) + "."
        let trimmed = ExplanationTrimmer.trimmed("\(long) \(long) \(long)")
        #expect(trimmed == long)
        #expect(trimmed.count <= ExplanationTrimmer.maximumCharacters)
    }

    @Test func oneEnormousSentenceIsCutAtAWordAndSaysSo() {
        let enormous = String(repeating: "word ", count: 200)
        let trimmed = ExplanationTrimmer.trimmed(enormous)
        #expect(trimmed.hasSuffix("…"))
        #expect(trimmed.count <= ExplanationTrimmer.maximumCharacters + 1)
        #expect(!trimmed.dropLast().hasSuffix(" "))
    }
}
