import Testing

@testable import TimbreKit

/// GDR-0032 through the real polisher. A snippet said alone never reaches
/// the model, so these hold on any Mac; the in-sentence path is measured
/// by `timbre-eval` (corpus cases 13 and 14).
struct PolishSnippetTests {

    private let snippets = [
        Snippet(say: "my email", text: "ada@example.com")!,
        Snippet(say: "status command", text: "git status --short")!,
    ]

    @Test("Said alone, a snippet is pasted as it is: no capital, no full stop")
    func alone() async {
        let polisher = TextPolisher()
        #expect(await polisher.polish("My email.", snippets: snippets) == "ada@example.com")
        #expect(await polisher.polish("Status command.", snippets: snippets) == "git status --short")
    }

    @Test("A taught correction can repair a mis-heard name before it is looked up")
    func correctedFirst() async {
        let corrections = [Correction(heard: "my e-mail", meant: "my email")!]
        let output = await TextPolisher().polish("My e-mail.", corrections: corrections, snippets: snippets)
        #expect(output == "ada@example.com")
    }

    @Test("In a sentence the text is exact, whatever the cleanup did around it")
    func inASentence() async {
        let output = await TextPolisher().polish("send it to my email", snippets: snippets)
        #expect(output.contains("ada@example.com"))
        #expect(!output.contains("SNIP"))
        #expect(output.hasSuffix("."))
    }
}
