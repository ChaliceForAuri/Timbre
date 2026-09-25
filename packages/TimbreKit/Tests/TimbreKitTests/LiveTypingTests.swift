import Testing

@testable import TimbreKit

struct LiveTypingTests {

    @Test func firstDeltaLosesItsLeadingSpace() {
        var typing = LiveTyping()
        #expect(typing.delta(for: " Okay, so the build") == "Okay, so the build")
        #expect(typing.typed == "Okay, so the build")
    }

    @Test func laterDeltasAreExact() {
        var typing = LiveTyping()
        _ = typing.delta(for: " The build is failing.")
        #expect(
            typing.delta(for: " The build is failing. It looks like signing.") == " It looks like signing.")
        #expect(typing.typed == "The build is failing. It looks like signing.")
    }

    @Test func nothingNewTypesNothing() {
        var typing = LiveTyping()
        _ = typing.delta(for: " Okay.")
        #expect(typing.delta(for: " Okay.") == "")
        #expect(typing.delta(for: "") == "")
    }

    @Test func revisedConfirmedTextTypesNothing() {
        var typing = LiveTyping()
        _ = typing.delta(for: " Okay, so")
        #expect(typing.delta(for: " Okay so the") == "")
        #expect(typing.typed == "Okay, so")
    }

    @Test func remainderIsWhatTheFieldStillLacks() {
        var typing = LiveTyping()
        _ = typing.delta(for: " The build is failing.")
        #expect(
            typing.remainder(of: "The build is failing. It looks like signing.") == " It looks like signing.")
        #expect(typing.remainder(of: "The build is failing.") == "")
    }

    @Test func remainderSkipsWhitespaceTheFieldAlreadyHas() {
        var typing = LiveTyping()
        _ = typing.delta(for: " Okay, so the build ")
        #expect(typing.remainder(of: "Okay, so the build is failing") == "is failing")
    }

    @Test func remainderIsNilWhenTheTranscriptDoesNotExtendTheRun() {
        var typing = LiveTyping()
        _ = typing.delta(for: " Okay, so")
        #expect(typing.remainder(of: "Something else entirely") == nil)
    }

    @Test func nothingTypedMeansTheWholeTranscriptRemains() {
        let typing = LiveTyping()
        #expect(typing.remainder(of: "Ship it on Friday.") == "Ship it on Friday.")
    }
}

struct ReplacementCheckTests {

    @Test func identicalRunMatches() {
        let run = "Okay, so the build is failing on CI."
        #expect(ReplacementCheck.matches(field: run, typed: run))
    }

    @Test func autocorrectedRunStillMatches() {
        // Autocorrect fixed a word and the app capitalised the start.
        #expect(
            ReplacementCheck.matches(
                field: "The build is failing on CI, it looks like a signing issue.",
                typed: "teh build is failing on CI it looks like a signing issue"
            )
        )
    }

    @Test func differentTextDoesNotMatch() {
        #expect(
            !ReplacementCheck.matches(
                field: "Dear Sam, thanks for the notes.", typed: "The build is failing on CI.")
        )
    }

    @Test func emptyTypedNeverMatches() {
        #expect(!ReplacementCheck.matches(field: "", typed: ""))
        #expect(!ReplacementCheck.matches(field: "Hello", typed: ""))
    }

    @Test func shortRunsGetASmallAllowance() {
        #expect(ReplacementCheck.matches(field: "Hi Sam", typed: "hi sam"))
        #expect(!ReplacementCheck.matches(field: "Hi Sam and everyone else", typed: "hi sam"))
    }
}

struct TranscriptSnapshotTests {

    @Test func textJoinsAndTrims() {
        let snapshot = TranscriptSnapshot(finalized: " Okay, so the build.", volatile: " it looks ")
        #expect(snapshot.text == "Okay, so the build. it looks")
        #expect(TranscriptSnapshot(finalized: "", volatile: "").text == "")
    }

    @Test func surrogatePairsStayWhole() {
        let units = Array(String(repeating: "a", count: 19).appending("😀b").utf16)
        let chunks = SyntheticText.chunks(of: units)
        #expect(chunks.count == 2)
        #expect(chunks[0].count == 19)
        #expect(String(decoding: chunks[1], as: UTF16.self) == "😀b")
    }
}
