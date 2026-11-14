import Foundation
import Testing

@testable import TimbreCore

/// GDR-0033: select, say learn, and it is in the Library.
struct LearnTargetTests {

    @Test("One word is a word; the punctuation a selection drags along is dropped")
    func word() {
        #expect(LearnTarget(selection: "idempotent") == .word("idempotent"))
        #expect(LearnTarget(selection: " idempotent, ") == .word("idempotent"))
        #expect(LearnTarget(selection: "(RBAC)") == .word("RBAC"))
        #expect(LearnTarget(selection: "“ephemeral”") == .word("ephemeral"))
    }

    @Test("Two to six words are a phrase; inner punctuation stays")
    func phrase() {
        #expect(LearnTarget(selection: "separation of concerns.") == .phrase("separation of concerns"))
        #expect(LearnTarget(selection: "table\n stakes") == .phrase("table stakes"))
        #expect(LearnTarget(selection: "state-of-the-art, mostly") == .phrase("state-of-the-art, mostly"))
        #expect(
            LearnTarget(selection: "one two three four five six") == .phrase("one two three four five six"))
    }

    @Test("A sentence is read, not learned; nothing is nothing")
    func neither() {
        #expect(LearnTarget(selection: "one two three four five six seven") == .tooLong)
        #expect(LearnTarget(selection: "  \n ") == .empty)
        #expect(LearnTarget(selection: "...") == .empty)
    }
}

struct LibraryLearnTests {

    private func library() -> (Library, URL) {
        let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
        return (
            Library(fileURL: directory.appending(path: "library.json"), device: .mac, legacy: nil), directory
        )
    }

    @Test("A learned word is saved with where it came from, and is due for practice like any other")
    func saves() throws {
        let (library, directory) = library()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(library.learn("idempotent,", app: "Slack") == .saved("idempotent"))
        let entry = try #require(library.entry("word:idempotent"))
        #expect(entry.source.how == .learned)
        #expect(entry.source.app == "Slack")
        #expect(entry.kind.isLearnable)
        #expect(library.terms == ["idempotent"])
        #expect(library.learn("separation of concerns") == .saved("separation of concerns"))
        #expect(library.entry("phrase:separation of concerns") != nil)
    }

    @Test("A term the Library already holds keeps its meaning and its history")
    func alreadyKnown() throws {
        let (library, directory) = library()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = Provenance(device: .mac, date: Date(timeIntervalSince1970: 1_700_000_000), how: .typed)
        library.upsert(
            try #require(
                LibraryEntry(
                    kind: .acronym, term: "RBAC", meaning: "Role-based access control", source: source)))
        let before = library.events.count
        #expect(library.learn("(RBAC)") == .alreadyKnown("RBAC"))
        #expect(library.learn("rbac") == .alreadyKnown("rbac"))
        #expect(library.events.count == before)
        #expect(library.entry("word:rbac") == nil)
    }

    @Test("Too much, or nothing, saves nothing")
    func refuses() {
        let (library, directory) = library()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(library.learn("this whole sentence is far too long to be a term") == .tooLong)
        #expect(library.learn("  ") == .nothing)
        #expect(library.entries.isEmpty)
    }
}
