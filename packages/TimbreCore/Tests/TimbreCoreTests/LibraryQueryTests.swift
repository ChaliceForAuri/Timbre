import Foundation
import Testing

@testable import TimbreCore

struct LibraryQueryTests {

    private let source = Provenance(device: .mac, date: Date(timeIntervalSince1970: 1_000_000), how: .typed)

    private var entries: [LibraryEntry] {
        [
            LibraryEntry(
                kind: .word, term: "café", meaning: "a small restaurant", tags: ["food"], source: source)!,
            LibraryEntry(
                kind: .acronym, term: "ADR", meaning: "Architecture Decision Record", source: source)!,
            LibraryEntry(kind: .correction, term: "TimbreKit", heard: "timber kit", source: source)!,
        ]
    }

    @Test func noKindAndNoSearchIsEverything() {
        #expect(LibraryQuery().apply(to: entries).count == 3)
    }

    @Test func filtersByKind() {
        #expect(LibraryQuery(kind: .acronym).apply(to: entries).map(\.term) == ["ADR"])
    }

    @Test func searchesTermHeardMeaningAndTagsIgnoringCaseAndDiacritics() {
        #expect(LibraryQuery(search: "cafe").apply(to: entries).map(\.term) == ["café"])
        #expect(LibraryQuery(search: "TIMBER").apply(to: entries).map(\.term) == ["TimbreKit"])
        #expect(LibraryQuery(search: "decision").apply(to: entries).map(\.term) == ["ADR"])
        #expect(LibraryQuery(search: "food").apply(to: entries).map(\.term) == ["café"])
        #expect(LibraryQuery(search: "  ").apply(to: entries).count == 3)
    }

    @Test func kindAndSearchCombine() {
        #expect(LibraryQuery(kind: .word, search: "record").apply(to: entries).isEmpty)
        #expect(LibraryQuery(kind: .acronym, search: "record").apply(to: entries).count == 1)
    }
}
