import Testing

@testable import TimbreKit

struct CorrectionTableTests {

    private func correction(_ heard: String, _ meant: String) -> Correction {
        Correction(heard: heard, meant: meant)!
    }

    @Test func replacesAWholePhraseIgnoringCaseAndKeepsPunctuation() {
        let out = CorrectionTable.applied(
            [correction("timber kit", "TimbreKit")],
            to: "I pushed Timber Kit, then timber kit again."
        )
        #expect(out == "I pushed TimbreKit, then TimbreKit again.")
    }

    @Test func doesNotMatchInsideOtherWords() {
        let out = CorrectionTable.applied([correction("kit", "Kit")], to: "the kitchen kit")
        #expect(out == "the kitchen Kit")
    }

    @Test func toleratesExtraWhitespaceInsideThePhrase() {
        let out = CorrectionTable.applied([correction("lang views", "Langfuse")], to: "to lang   views now")
        #expect(out == "to Langfuse now")
    }

    @Test func longestPhraseWins() {
        let out = CorrectionTable.applied(
            [correction("views", "Views"), correction("lang views", "Langfuse")],
            to: "lang views and views"
        )
        #expect(out == "Langfuse and Views")
    }

    @Test func aCorrectionCanExpandToSeveralWords() {
        let out = CorrectionTable.applied(
            [correction("superbasin", "Supabase and")],
            to: "talks to superbasin lang views"
        )
        #expect(out == "talks to Supabase and lang views")
    }

    @Test func phrasesEndingInSymbolsStillMatch() {
        let out = CorrectionTable.applied([correction("c plus plus", "C++")], to: "I write c plus plus daily")
        #expect(out == "I write C++ daily")
        let again = CorrectionTable.applied([correction("c++", "C++")], to: "c++ is fine")
        #expect(again == "C++ is fine")
    }

    @Test func regexMetacharactersInThePhraseAreLiteral() {
        let out = CorrectionTable.applied([correction("a.b", "AB")], to: "a.b but not axb")
        #expect(out == "AB but not axb")
    }

    @Test func nothingTaughtMeansNothingChanged() {
        #expect(CorrectionTable.applied([], to: "unchanged") == "unchanged")
    }
}
