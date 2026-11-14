import Foundation
import Testing

@testable import TimbreCore

/// GDR-0032: a name said, exact text written.
struct SnippetTableTests {

    private let snippets = [
        Snippet(say: "my email", text: "ada@example.com")!,
        Snippet(say: "my work email", text: "ada.lovelace@work.example")!,
        Snippet(say: "status command", text: "git status --short --branch")!,
        Snippet(say: "my signature", text: "Kind regards,\nAda")!,
    ]

    @Test("An utterance that is only the name is the text, whatever the transcriber did to it")
    func whole() {
        #expect(SnippetTable.whole(snippets, utterance: "My email.") == "ada@example.com")
        #expect(SnippetTable.whole(snippets, utterance: "  my   EMAIL ") == "ada@example.com")
        #expect(SnippetTable.whole(snippets, utterance: "My work email!") == "ada.lovelace@work.example")
        #expect(SnippetTable.whole(snippets, utterance: "My signature.") == "Kind regards,\nAda")
    }

    @Test("Anything more than the name is a sentence, not the snippet")
    func notWhole() {
        #expect(SnippetTable.whole(snippets, utterance: "Send my email.") == nil)
        #expect(SnippetTable.whole(snippets, utterance: "my emails") == nil)
        #expect(SnippetTable.whole(snippets, utterance: "") == nil)
        #expect(SnippetTable.whole([], utterance: "my email") == nil)
    }

    @Test("Inside a sentence the longest name wins, and whole words only")
    func guardedInASentence() {
        let guarded = SnippetTable.guarded(snippets, in: "Reach me at my work email, not my email.")
        #expect(guarded.text == "Reach me at SNIP1, not SNIP2.")
        #expect(guarded.texts == ["ada.lovelace@work.example", "ada@example.com"])
        // "my emails" is another word.
        #expect(SnippetTable.guarded(snippets, in: "I read my emails.").texts.isEmpty)
    }

    @Test("The text comes back exact, after the sentence rules have run")
    func restored() {
        let guarded = SnippetTable.guarded(snippets, in: "status command is what I run, then my signature")
        let sentence = guarded.text.replacingOccurrences(of: "then", with: "Then") + "."
        #expect(
            SnippetTable.restored(sentence, from: guarded)
                == "git status --short --branch is what I run, Then Kind regards,\nAda.")
    }

    @Test("A lowercased placeholder is still restored; a lost one is noticed")
    func keptAll() {
        let guarded = SnippetTable.guarded(snippets, in: "Send it to my email")
        #expect(SnippetTable.keptAll(guarded, in: "Send it to snip1."))
        #expect(SnippetTable.restored("Send it to snip1.", from: guarded) == "Send it to ada@example.com.")
        #expect(!SnippetTable.keptAll(guarded, in: "Send it."))
        #expect(!SnippetTable.keptAll(guarded, in: "Send it to SNIP12."))
    }

    @Test("A name said twice is two placeholders, and losing either is noticed")
    func saidTwice() {
        let guarded = SnippetTable.guarded(snippets, in: "give him my email and give her my email too")
        #expect(guarded.text == "give him SNIP1 and give her SNIP2 too")
        #expect(guarded.texts == ["ada@example.com", "ada@example.com"])
        #expect(!SnippetTable.keptAll(guarded, in: "Give him SNIP1 and her too."))
        #expect(!SnippetTable.keptAll(guarded, in: "Give him SNIP1 and her SNIP1 too."))
        #expect(
            SnippetTable.restored("Give him SNIP1 and her SNIP2 too.", from: guarded)
                == "Give him ada@example.com and her ada@example.com too.")
    }

    @Test("A snippet whose text looks like a placeholder is written, not expanded again")
    func placeholderShapedText() {
        let odd = [Snippet(say: "first thing", text: "SNIP2")!, Snippet(say: "other", text: "two")!]
        let guarded = SnippetTable.guarded(odd, in: "first thing then other")
        #expect(SnippetTable.restored(guarded.text, from: guarded) == "SNIP2 then two")
    }

    @Test("What a snippet wrote is not what the user said")
    func withoutTexts() {
        let out = SnippetTable.withoutTexts(
            snippets, in: "Run git status --short --branch, then email ada@example.com.")
        #expect(!out.contains("git status"))
        #expect(!out.contains("ada@example.com"))
        #expect(out.contains("then email"))
    }

    @Test("A text with regex or replacement characters is written as it is")
    func literalText() {
        let odd = [Snippet(say: "the pattern", text: #"^\d+$ costs $0 \1"#)!]
        let guarded = SnippetTable.guarded(odd, in: "Use the pattern here")
        #expect(SnippetTable.restored(guarded.text, from: guarded) == #"Use ^\d+$ costs $0 \1 here"#)
    }

    @Test("Twelve snippets in one sentence do not collide")
    func manyPlaceholders() {
        let many = (1...12).map { Snippet(say: "item \(numberWord($0))", text: "<\($0)>")! }
        let said = many.map(\.say).joined(separator: " and ")
        let guarded = SnippetTable.guarded(many, in: said)
        let back = SnippetTable.restored(guarded.text, from: guarded)
        #expect(back == (1...12).map { "<\($0)>" }.joined(separator: " and "))
    }

    private func numberWord(_ n: Int) -> String {
        ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"][
            n - 1]
    }
}

struct SnippetEntryTests {
    private let source = Provenance(
        device: .mac, date: Date(timeIntervalSince1970: 1_700_000_000), how: .typed)

    @Test("A snippet is an entry by its spoken name, and is never practised")
    func entry() throws {
        let entry = try #require(
            LibraryEntry(kind: .snippet, term: "ada@example.com", heard: "My  Email", source: source))
        #expect(entry.id == "snippet:my email")
        #expect(!entry.kind.isLearnable)
        #expect(LibraryEntry(kind: .snippet, term: "ada@example.com", source: source) == nil)
        #expect(LibraryEntry(kind: .snippet, term: " ", heard: "my email", source: source) == nil)
    }

    @Test("The Library hands the pipeline its snippets, and they are not vocabulary")
    func library() throws {
        let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = Library(fileURL: directory.appending(path: "library.json"), device: .mac, legacy: nil)
        library.upsert(
            try #require(
                LibraryEntry(kind: .snippet, term: "ada@example.com", heard: "my email", source: source)))
        #expect(library.snippets == [Snippet(say: "my email", text: "ada@example.com")!])
        #expect(library.terms.isEmpty)
        #expect(library.corrections.isEmpty)
    }
}
