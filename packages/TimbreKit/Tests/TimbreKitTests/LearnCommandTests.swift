import Testing

@testable import TimbreKit

/// GDR-0033: "learn" is a command word, and it never rewrites text.
struct LearnCommandTests {

    @Test func theWordIsRecognised() {
        #expect(VoiceCommand.parse("learn") == .learn)
        #expect(VoiceCommand.parse("Learn this.") == .learn)
        #expect(VoiceCommand.recognized(in: "I want to memorise that") == .learn)
        #expect(!VoiceCommand.learn.rewritesText)
    }

    @Test("To-do words do not fire it")
    func notATodo() {
        #expect(VoiceCommand.recognized(in: "remember the milk") == nil)
        #expect(VoiceCommand.recognized(in: "save the file on Friday") == nil)
    }

    @Test("A half-spoken word waits: only explain may fire on a prefix")
    func noPrefixFiring() {
        #expect(VoiceCommand.recognizedWhileSpeaking(in: "Lea") == nil)
        #expect(VoiceCommand.recognizedWhileSpeaking(in: "Learn") == .learn)
    }

    @Test("The card and the pill say what learn did")
    func captions() {
        #expect(
            DictationController.caption("On-device model · may be wrong", learned: .saved("idempotent"))
                == "Saved to your Library · On-device model · may be wrong")
        #expect(
            DictationController.caption("Your definition", learned: .alreadyKnown("RBAC"))
                == "Already in your Library · Your definition")
        #expect(DictationController.caption("Your definition", learned: nil) == "Your definition")
        #expect(
            DictationController.learnedNotice(.saved("idempotent")) == "Saved “idempotent” to your Library.")
        #expect(DictationController.learnedNotice(nil) == nil)
    }
}
