import Foundation
import Testing

@testable import TimbreCore

struct MergeTests {

    private let source = Provenance(device: .mac, date: Date(timeIntervalSince1970: 1_000_000), how: .typed)

    private func event(
        _ kind: LibraryEvent.Kind, _ entry: String, at seconds: TimeInterval, on device: Device = .mac
    )
        -> LibraryEvent
    {
        LibraryEvent(entry: entry, kind: kind, date: Date(timeIntervalSince1970: seconds), device: device)
    }

    @Test func eventsUnionDedupesAndOrders() {
        let a = [event(.taught, "word:a", at: 20), event(.met, "word:a", at: 30)]
        let b = [event(.met, "word:a", at: 30), event(.taught, "word:b", at: 10, on: .iPhone)]
        let merged = LibraryMerge.events(a, b)
        #expect(merged.map(\.kind) == [.taught, .taught, .met])
        #expect(merged.count == 3)
    }

    @Test func entriesTakeTheLatestEdit() {
        var mine = LibraryEntry(
            kind: .acronym, term: "ADR", meaning: "Alternative Dispute Resolution", source: source)!
        var theirs = mine
        mine.edited = Date(timeIntervalSince1970: 2_000_000)
        theirs.meaning = "Architecture Decision Record"
        theirs.edited = Date(timeIntervalSince1970: 3_000_000)
        let merged = LibraryMerge.entries([mine], [theirs], events: [])
        #expect(merged.map(\.meaning) == ["Architecture Decision Record"])
    }

    @Test func aLaterTombstoneRemovesAnEntry() {
        let entry = LibraryEntry(kind: .word, term: "gone", source: source)!
        let forgot = event(.forgot, entry.id, at: 1_500_000, on: .iPhone)
        #expect(LibraryMerge.entries([entry], [], events: [forgot]).isEmpty)
    }

    @Test func reAddingAfterATombstoneSurvives() {
        let forgot = event(.forgot, "word:back", at: 1_500_000)
        let again = LibraryEntry(
            kind: .word, term: "back",
            source: Provenance(device: .mac, date: Date(timeIntervalSince1970: 1_600_000), how: .typed))!
        #expect(LibraryMerge.entries([], [again], events: [forgot]).map(\.term) == ["back"])
    }

    @Test func localOrderIsKeptAndRemoteAppended() {
        let a = LibraryEntry(kind: .word, term: "a", source: source)!
        let b = LibraryEntry(kind: .word, term: "b", source: source)!
        let c = LibraryEntry(kind: .word, term: "c", source: source)!
        #expect(LibraryMerge.entries([b, a], [c, a], events: []).map(\.term) == ["b", "a", "c"])
    }
}
