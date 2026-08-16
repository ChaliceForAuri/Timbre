import Testing

@testable import SpokeKit

struct TextPolisherPromptTests {

    @Test func bareTranscriptGetsOnlyTheCleanupRequest() {
        let prompt = TextPolisher.makePrompt(transcript: "hello world", appContext: nil, vocabulary: [])
        #expect(prompt.contains("hello world"))
        #expect(!prompt.contains("pasted into"))
        #expect(!prompt.contains("spelled correctly"))
    }

    @Test func appContextIsWovenIn() {
        let prompt = TextPolisher.makePrompt(transcript: "hi", appContext: "Slack", vocabulary: [])
        #expect(prompt.contains("pasted into Slack"))
    }

    @Test func emptyAppContextIsOmitted() {
        let prompt = TextPolisher.makePrompt(transcript: "hi", appContext: "", vocabulary: [])
        #expect(!prompt.contains("pasted into"))
    }

    @Test func vocabularyIsListed() {
        let prompt = TextPolisher.makePrompt(
            transcript: "hi",
            appContext: nil,
            vocabulary: ["Anthropic", "SwiftUI"]
        )
        #expect(prompt.contains("Anthropic, SwiftUI"))
    }

    @Test func vocabularyIsCappedAtSixtyTerms() {
        let vocabulary = (1...100).map { "term\($0)" }
        let prompt = TextPolisher.makePrompt(transcript: "hi", appContext: nil, vocabulary: vocabulary)
        #expect(prompt.contains("term60"))
        #expect(!prompt.contains("term61"))
    }

    @Test func transcriptComesLast() {
        // The model weighs the end of a prompt most heavily; the transcript
        // must be the final thing it reads.
        let prompt = TextPolisher.makePrompt(
            transcript: "the actual dictation",
            appContext: "Mail",
            vocabulary: ["Spoke"]
        )
        let transcriptRange = prompt.range(of: "the actual dictation")!
        #expect(prompt[transcriptRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
