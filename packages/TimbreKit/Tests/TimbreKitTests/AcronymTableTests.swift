import Foundation
import Testing

@testable import TimbreKit

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

    @Test func groundsTheExplainPromptInWhatWasTaught() {
        let prompt = TextTransformer.makePrompt(
            for: .explain, text: "Write an ADR.", known: [taught[0]]
        )
        #expect(prompt.contains("ADR means Architecture Decision Record"))
        #expect(!TextTransformer.makePrompt(for: .explain, text: "Write an ADR.").contains("dictionary"))
    }

    @Test func definingPersistsAndRedefiningReplaces() {
        let suiteName = "TimbreKitTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = VocabularyStore(defaults: defaults)
        #expect(!store.define(term: " ", meaning: "nothing"))
        store.define(term: "ADR", meaning: "Alternative Dispute Resolution")
        store.define(term: "ADR", meaning: "Architecture Decision Record")

        let reloaded = VocabularyStore(defaults: defaults)
        #expect(reloaded.acronyms.map(\.meaning) == ["Architecture Decision Record"])
        reloaded.undefine(reloaded.acronyms[0])
        #expect(VocabularyStore(defaults: defaults).acronyms.isEmpty)
    }
}
