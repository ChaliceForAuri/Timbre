import Testing

@testable import TimbreKit

struct AppleDictionaryTests {

    @Test func readsThePronunciationBetweenTheBarsAndTheFirstParagraph() {
        let raw =
            "ephemeral | əˈfem(ə)rəl | adjective lasting for a very short time: fashions are ephemeral.\n"
            + "noun an ephemeral plant.\nORIGIN late 16th century…"
        let entry = AppleDictionary.parse(raw, term: "Ephemeral")
        #expect(entry?.pronunciation == "əˈfem(ə)rəl")
        #expect(entry?.text == "adjective lasting for a very short time: fashions are ephemeral.")
    }

    @Test func copesWithNoBars() {
        let entry = AppleDictionary.parse("tacit understood or implied without being stated.", term: "tacit")
        #expect(
            entry
                == AppleDictionary.Entry(
                    pronunciation: nil, text: "understood or implied without being stated."))
        #expect(AppleDictionary.parse("   ", term: "x") == nil)
    }

    @Test func cutsLongEntriesAtASentenceEnd() {
        let long =
            "adjective " + Array(repeating: "very long sense here", count: 20).joined(separator: "; ") + "."
        let cut = AppleDictionary.truncated(long, to: 240)
        #expect(cut.count <= 241)
        #expect(cut.hasSuffix(";") || cut.hasSuffix("…"))
    }
}
