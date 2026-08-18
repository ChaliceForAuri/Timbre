import Testing

@testable import SpokeKit

@Suite("SentenceTerminator")
struct SentenceTerminatorTests {

    @Test("Adds a full stop to text ending in a word")
    func terminatesSentence() {
        #expect(SentenceTerminator.terminated("the deploy went out") == "the deploy went out.")
        #expect(SentenceTerminator.terminated("the meeting is at 3") == "the meeting is at 3.")
    }

    @Test("Leaves text that already ends a sentence")
    func leavesTerminated() {
        for text in ["Ship it.", "Ship it!", "Ship it?", "Well\u{2026}"] {
            #expect(SentenceTerminator.terminated(text) == text)
        }
    }

    /// Appending after a clause mark would produce ",." — worse than the
    /// problem it was trying to fix.
    @Test("Leaves clause marks alone")
    func leavesClauseMarks() {
        for text in ["ship it,", "ship it;", "ship it:", "ship it —"] {
            #expect(SentenceTerminator.terminated(text) == text)
        }
    }

    @Test("Looks past closing quotes and brackets")
    func handlesClosers() {
        #expect(SentenceTerminator.terminated("He said \"stop\"") == "He said \"stop\".")
        #expect(SentenceTerminator.terminated("(see the docs.)") == "(see the docs.)")
        #expect(SentenceTerminator.terminated("(see the docs)") == "(see the docs).")
        #expect(SentenceTerminator.terminated("He asked \"why?\"") == "He asked \"why?\"")
    }

    /// The allowlist earning its keep: nobody writes "sounds good 👍." and no
    /// rule had to anticipate emoji for that to hold.
    @Test("Leaves endings that are neither letter nor digit")
    func leavesNonWordEndings() {
        #expect(SentenceTerminator.terminated("sounds good 👍") == "sounds good 👍")
        #expect(SentenceTerminator.terminated("wait -") == "wait -")
    }

    @Test("Only the end of multi-line text is terminated")
    func handlesMultipleLines() {
        let text = "Send it to the team.\n\nLet me know if anything breaks"
        #expect(
            SentenceTerminator.terminated(text)
                == "Send it to the team.\n\nLet me know if anything breaks."
        )
    }

    @Test("Empty and whitespace-only text stay empty")
    func handlesEmpty() {
        #expect(SentenceTerminator.terminated("") == "")
        #expect(SentenceTerminator.terminated("   \n ") == "")
    }
}
