import Testing

@testable import TimbreKit

struct CommandHoldTests {

    @Test func aCommandWordFiresOnceWhileHeld() {
        var hold = CommandHold()
        #expect(hold.heard("") == nil)
        #expect(hold.heard("Fix") == .fix)
        #expect(hold.heard("Fix this") == nil)
        #expect(hold.hasDecided)
    }

    /// Silence mid-hold is "not yet", never "fix".
    @Test func silenceNeverFiresLive() {
        var hold = CommandHold()
        #expect(hold.heard("   ") == nil)
        #expect(!hold.hasDecided)
    }

    @Test func releasingAfterALiveCommandDoesNothing() {
        var hold = CommandHold()
        _ = hold.heard("Explain this")
        #expect(hold.beginRelease() == .alreadyHandled)
        #expect(hold.resolve(finalTranscript: "explain this") == .alreadyHandled)
    }

    /// The race this type exists for: the key comes up, and while the final
    /// transcript is fetched a late live result carries the word. It must
    /// not run a second time.
    @Test func aLateLiveResultDuringReleaseDoesNotFireTwice() {
        var hold = CommandHold()
        #expect(hold.beginRelease() == nil)
        #expect(hold.heard("Shorten") == nil)
        #expect(hold.resolve(finalTranscript: "Shorten.") == .run(.shorten))
        #expect(hold.resolve(finalTranscript: "Shorten.") == .alreadyHandled)
    }

    @Test func aSilentReleaseMeansFix() {
        var hold = CommandHold()
        _ = hold.beginRelease()
        #expect(hold.resolve(finalTranscript: "") == .run(.fix))
    }

    @Test func unknownWordsAreReportedNotRun() {
        var hold = CommandHold()
        #expect(hold.heard("Jordan") == nil)
        _ = hold.beginRelease()
        #expect(hold.resolve(finalTranscript: " Jordan. ") == .unrecognised("Jordan."))
    }

    @Test func interruptionsOnlyCountBeforeACommandFires() {
        var hold = CommandHold()
        #expect(hold.acceptsInterruption)
        _ = hold.heard("Explain")
        #expect(!hold.acceptsInterruption)
    }
}

struct LiveRecognitionTests {

    /// Exactly the partials the transcriber produced, measured 2026-09-24.
    @Test(arguments: ["Expl", "Expl.", "Acr", "Ex pl", "Defi", "Wha"])
    func explainFiresOnAClearPartial(partial: String) {
        let expected: VoiceCommand? = partial == "Ex pl" ? nil : .explain
        #expect(VoiceCommand.recognizedWhileSpeaking(in: partial) == expected)
    }

    /// Two letters is not a word yet.
    @Test func tooShortToCommitTo() {
        #expect(VoiceCommand.recognizedWhileSpeaking(in: "Ex") == nil)
        #expect(VoiceCommand.recognizedWhileSpeaking(in: "Ac") == nil)
    }

    /// Fix and shorten rewrite text, so they wait for a whole word.
    @Test func destructiveCommandsNeedTheWholeWord() {
        #expect(VoiceCommand.recognizedWhileSpeaking(in: "Fi") == nil)
        #expect(VoiceCommand.recognizedWhileSpeaking(in: "Shor") == nil)
        #expect(VoiceCommand.recognizedWhileSpeaking(in: "Short") == .shorten)
        #expect(VoiceCommand.recognizedWhileSpeaking(in: "Fix") == .fix)
    }

    /// A prefix shared with a destructive word must not fire explain: "co"
    /// could be "correct" (fix) or "concise" (shorten).
    @Test func anAmbiguousPrefixWaits() {
        #expect(VoiceCommand.recognizedWhileSpeaking(in: "Con") == nil)
        #expect(VoiceCommand.recognizedWhileSpeaking(in: "Cor") == nil)
    }

    /// Only the word still being spoken may be partial.
    @Test func earlierWordsMustBeWhole() {
        #expect(VoiceCommand.recognizedWhileSpeaking(in: "acr the board") == nil)
    }
}

struct ExplanationFullnessTests {

    @Test func fullOnceASentencePastTheMaximumHasBegun() {
        #expect(!ExplanationTrimmer.isFull("One. Two. Three."))
        #expect(ExplanationTrimmer.isFull("One. Two. Three. Fo"))
    }

    @Test func fullPastTheLengthLimit() {
        #expect(ExplanationTrimmer.isFull(String(repeating: "word ", count: 100)))
    }

    @Test func aStreamingFirstSentenceIsNotFull() {
        #expect(!ExplanationTrimmer.isFull("API stands for Application Programming"))
    }
}
