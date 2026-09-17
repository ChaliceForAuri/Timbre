import Testing

@testable import TimbreKit

struct VoiceCommandTests {

    @Test func silenceMeansFix() {
        #expect(VoiceCommand.parse("") == .fix)
        #expect(VoiceCommand.parse("  \n") == .fix)
    }

    /// Exactly what the transcriber produced for each spoken phrase, two
    /// synthetic voices, measured 2026-09-17 — punctuation and capitals included.
    @Test(
        arguments: [
            ("Fix.", VoiceCommand.fix), ("Fix this.", .fix), ("Fix it.", .fix),
            ("Explain.", .explain), ("Explain this.", .explain), ("Acronym.", .explain),
            ("Shorten.", .shorten), ("Shorten this.", .shorten), ("Make it shorter.", .shorten),
            ("Shorter.", .shorten),
        ]
    )
    func recognisesWhatTheTranscriberEmits(transcript: String, expected: VoiceCommand) {
        #expect(VoiceCommand.parse(transcript) == expected)
    }

    /// One voice's bare "shorten" came back as "Jordan". Two of the three
    /// commands rewrite the user's text, so an unknown word must do nothing.
    @Test func anUnknownWordIsNotRoundedToACommand() {
        #expect(VoiceCommand.parse("Jordan.") == nil)
        #expect(VoiceCommand.parse("hello there") == nil)
    }

    @Test func theFirstRecognisedWordWins() {
        #expect(VoiceCommand.parse("please explain this, don't shorten it") == .explain)
    }

    @Test func matchesWholeWordsOnly() {
        #expect(VoiceCommand.parse("prefix") == nil)
        #expect(VoiceCommand.parse("shortcake") == nil)
    }
}
