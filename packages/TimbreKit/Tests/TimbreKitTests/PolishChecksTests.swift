import Foundation
import Testing

@testable import TimbreKit

@Suite("PolishChecks")
struct PolishChecksTests {

    private let sample = DictationCase(
        id: "sample",
        transcript: "so um we should ship it on Friday",
        forbidden: ["um"],
        required: ["Friday"],
        requiresPunctuation: true
    )

    @Test("Clean output passes every check")
    func passes() {
        #expect(PolishChecks.failures(for: sample, output: "We should ship it on Friday.").isEmpty)
    }

    @Test("Surviving filler fails")
    func catchesFiller() {
        let failures = PolishChecks.failures(for: sample, output: "So um we should ship it Friday.")
        #expect(failures.contains { $0.contains("um") })
    }

    @Test("Lost content fails")
    func catchesLostContent() {
        let failures = PolishChecks.failures(for: sample, output: "We should ship it.")
        #expect(failures.contains { $0.contains("Friday") })
    }

    @Test("Missing sentence punctuation fails when required")
    func catchesMissingPunctuation() {
        let failures = PolishChecks.failures(for: sample, output: "We should ship it on Friday")
        #expect(failures.contains { $0.contains("punctuation") })
    }

    /// Empty output short-circuits: reporting "lost Friday" as well would be
    /// noise when the real problem is that nothing came back.
    @Test("Empty output reports one failure, not every check")
    func emptyShortCircuits() {
        #expect(PolishChecks.failures(for: sample, output: "   ") == ["produced no output"])
    }

    @Test("Corpus JSON decodes with fields omitted")
    func decodesSparseCase() throws {
        let json = #"{"cases":[{"id":"x","transcript":"hello there"}]}"#
        let corpus = try JSONDecoder().decode(DictationCorpus.self, from: Data(json.utf8))
        let only = try #require(corpus.cases.first)
        #expect(only.id == "x")
        #expect(only.forbidden.isEmpty)
        #expect(only.requiresPunctuation == false)
    }

    @Test("A case with one right answer fails on anything else (GDR-0032)")
    func exact() {
        let alone = DictationCase(
            id: "alone", transcript: "My email.",
            snippets: [Snippet(say: "my email", text: "ada@example.com")!],
            exact: "ada@example.com")
        #expect(PolishChecks.failures(for: alone, output: "ada@example.com").isEmpty)
        let wrong = PolishChecks.failures(for: alone, output: "Ada@example.com.")
        #expect(wrong.contains { $0.contains("is not exactly") })
    }

    @Test("Output that opens with a snippet's text need not start with a capital; anything else must")
    func snippetStart() {
        let opens = DictationCase(
            id: "opens", transcript: "status command runs first",
            snippets: [Snippet(say: "status command", text: "git status")!])
        #expect(PolishChecks.failures(for: opens, output: "git status runs first.").isEmpty)
        let lower = PolishChecks.failures(for: opens, output: "then git status runs.")
        #expect(lower.contains { $0.contains("capital") })
    }
}
