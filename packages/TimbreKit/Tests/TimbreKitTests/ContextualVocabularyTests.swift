import Testing

@testable import TimbreKit

struct ContextualVocabularyTests {

    @Test func trimsDropsEmptiesAndDeduplicatesKeepingOrder() {
        let strings = ContextualVocabulary.strings(from: [" SwiftUI ", "", "TimbreKit", "SwiftUI", "  "])
        #expect(strings == ["SwiftUI", "TimbreKit"])
    }

    /// The word taught a minute ago must make the list; if anything is
    /// dropped it is the oldest.
    @Test func keepsTheNewestTermsWhenOverTheLimit() {
        let terms = (1...(ContextualVocabulary.limit + 5)).map { "term\($0)" }
        let strings = ContextualVocabulary.strings(from: terms)
        #expect(strings.count == ContextualVocabulary.limit)
        #expect(strings.first == "term6")
        #expect(strings.last == "term\(ContextualVocabulary.limit + 5)")
    }

    @Test func missingTermsIsCaseAndSpacingSensitive() {
        let transcript = "the Swift UI settings use TimbreKit"
        let missing = ContextualVocabulary.missingTerms(
            from: ["SwiftUI", "TimbreKit", "timbrekit"],
            in: transcript
        )
        #expect(missing == ["SwiftUI", "timbrekit"])
    }

    @Test func nothingIsMissingFromAnEmptyVocabulary() {
        #expect(ContextualVocabulary.missingTerms(from: [], in: "anything").isEmpty)
    }
}
