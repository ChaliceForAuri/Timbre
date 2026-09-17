import Testing

@testable import TimbreKit

struct OutputCleanerTests {

    @Test func removesAMirroredFence() {
        let output = "\"\"\"\nThe release slips to Friday.\n\"\"\""
        #expect(OutputCleaner.unwrapped(output, original: "whatever") == "The release slips to Friday.")
    }

    @Test func removesQuotesTheModelAddedAroundItsWholeAnswer() {
        #expect(OutputCleaner.unwrapped("\"Ship Friday.\"", original: "We ship on Friday.") == "Ship Friday.")
        #expect(OutputCleaner.unwrapped("“Ship Friday.”", original: "We ship on Friday.") == "Ship Friday.")
    }

    /// The author quoting someone is theirs to keep.
    @Test func keepsQuotesThatWereTheAuthorsOwn() {
        let answer = "\"Ship it,\" she said."
        #expect(OutputCleaner.unwrapped(answer, original: "\"Just ship it,\" she said, again.") == answer)
        #expect(
            OutputCleaner.unwrapped("He said \"no\" and \"never\"", original: "x")
                == "He said \"no\" and \"never\"")
    }
}
