import Testing

@testable import TimbreKit

@Suite("SpokenCommands")
struct SpokenCommandsTests {

    @Test("Structural commands become the breaks they name")
    func replacesStructuralCommands() {
        #expect(
            SpokenCommands.applied(to: "send it to the team new paragraph let me know")
                == "send it to the team\n\nlet me know"
        )
        #expect(SpokenCommands.applied(to: "first new line second") == "first\nsecond")
    }

    @Test("Bullet point opens a list item")
    func replacesBulletPoint() {
        #expect(
            SpokenCommands.applied(to: "todo bullet point ship it") == "todo\n• ship it"
        )
    }

    /// GDR-0003: these are ordinary English words, so Timbre leaves them alone
    /// and lets the polisher punctuate instead.
    @Test("Punctuation commands are not commands")
    func leavesPunctuationWords() {
        let text = "the Victorian period was a comma in history"
        #expect(SpokenCommands.applied(to: text) == text)
        #expect(SpokenCommands.applied(to: "send it period") == "send it period")
    }

    @Test("Matching respects word boundaries and case")
    func respectsBoundariesAndCase() {
        // "newline" is one word — not the command.
        #expect(SpokenCommands.applied(to: "add a newline character") == "add a newline character")
        #expect(SpokenCommands.applied(to: "one New Paragraph two") == "one\n\ntwo")
    }

    @Test("Consecutive commands collapse cleanly")
    func handlesConsecutiveCommands() {
        #expect(SpokenCommands.applied(to: "a new line new line b") == "a\n\nb")
    }

    @Test("Leading and trailing commands leave no stray whitespace")
    func trimsEdges() {
        #expect(SpokenCommands.applied(to: "new paragraph hello") == "hello")
        #expect(SpokenCommands.applied(to: "hello new paragraph") == "hello")
    }
}
