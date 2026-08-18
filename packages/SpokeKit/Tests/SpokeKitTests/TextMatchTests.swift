import Testing

@testable import SpokeKit

@Suite("TextMatch")
struct TextMatchTests {

    @Test("Normalization lowercases and strips punctuation")
    func normalizes() {
        #expect(TextMatch.normalized("Don't — ship it, Friday.") == "don t ship it friday")
        #expect(TextMatch.normalized("  spaced   out  ") == "spaced out")
        #expect(TextMatch.normalized("...") == "")
    }

    /// The whole reason this type exists rather than a plain `contains`.
    @Test("Matching respects word boundaries")
    func respectsWordBoundaries() {
        #expect(TextMatch.containsPhrase("um", in: "so um yeah"))
        #expect(!TextMatch.containsPhrase("um", in: "the number was wrong"))
        #expect(!TextMatch.containsPhrase("um", in: "his album"))
    }

    @Test("Matching ignores punctuation the model is free to add")
    func ignoresPunctuation() {
        #expect(TextMatch.containsPhrase("ship it Friday", in: "We'll ship it, Friday."))
        #expect(TextMatch.containsPhrase("PR", in: "Take a look at the PR?"))
    }

    @Test("Doubled words are matchable as a phrase")
    func matchesRepeatedWords() {
        #expect(TextMatch.containsPhrase("the the", in: "go with the the second option"))
        #expect(!TextMatch.containsPhrase("the the", in: "go with the second option"))
    }

    @Test("A phrase with no alphanumerics never matches")
    func emptyNeverMatches() {
        #expect(!TextMatch.containsPhrase("", in: "anything"))
        #expect(!TextMatch.containsPhrase("!!!", in: "anything"))
    }
}
