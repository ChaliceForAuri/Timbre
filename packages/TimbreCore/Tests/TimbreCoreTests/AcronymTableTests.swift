import Testing

@testable import TimbreCore

struct AcronymTableTests {

    private let taught = [
        Acronym(term: "ADR", meaning: "Architecture Decision Record")!,
        Acronym(term: "IT", meaning: "Information Technology")!,
        Acronym(term: "CI/CD", meaning: "Continuous integration and delivery")!,
    ]

    @Test func aSelectionThatIsTheTermGetsTheTaughtAnswer() {
        #expect(AcronymTable.exactAnswer(for: " ADR. ", from: taught) == "ADR — Architecture Decision Record")
        #expect(
            AcronymTable.exactAnswer(for: "(CI/CD)", from: taught)
                == "CI/CD — Continuous integration and delivery")
    }

    /// An acronym is its capitals: "it" is a pronoun, not Information Technology.
    @Test func matchingIsCaseSensitiveAndWholeWord() {
        #expect(AcronymTable.exactAnswer(for: "it", from: taught) == nil)
        #expect(
            AcronymTable.matches(in: "it broke in IT again, says the ADRs team", from: taught).map(\.term)
                == ["IT"])
    }

    @Test func findsTaughtTermsInsideASentence() {
        let found = AcronymTable.matches(
            in: "We record every choice as an ADR before CI/CD runs.", from: taught)
        #expect(found.map(\.term) == ["ADR", "CI/CD"])
    }
}
