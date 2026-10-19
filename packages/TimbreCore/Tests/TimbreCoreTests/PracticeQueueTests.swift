import Foundation
import Testing

@testable import TimbreCore

struct PracticeQueueTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let source = Provenance(device: .mac, date: Date(timeIntervalSince1970: 1_000_000), how: .typed)

    private func taught(_ id: String, daysAgo: Double) -> LibraryEvent {
        LibraryEvent(entry: id, kind: .taught, date: now.addingTimeInterval(-daysAgo * 86400), device: .mac)
    }

    @Test func dueWeakestFirstThenFreshestAndNeverCorrections() {
        let old = LibraryEntry(kind: .word, term: "old", source: source)!
        let older = LibraryEntry(kind: .word, term: "older", source: source)!
        let fresh = LibraryEntry(kind: .phrase, term: "fresh", source: source)!
        let fresher = LibraryEntry(kind: .acronym, term: "NEW", meaning: "newest", source: source)!
        let correction = LibraryEntry(
            kind: .correction, term: "TimbreKit", heard: "timber kit", source: source)!
        let events = [
            taught(old.id, daysAgo: 10), taught(older.id, daysAgo: 20), taught(fresh.id, daysAgo: 1),
            taught(fresher.id, daysAgo: 0.5), taught(correction.id, daysAgo: 30),
        ]
        let queue = PracticeQueue.next(
            from: [fresh, old, correction, fresher, older], events: events, at: now)
        #expect(queue.map(\.term) == ["older", "old", "NEW", "fresh"])
        #expect(
            PracticeQueue.next(from: [fresh, old], events: events, at: now, limit: 1).map(\.term) == ["old"])
    }

    @Test func anEntryWithNoHistoryWaits() {
        let silent = LibraryEntry(kind: .word, term: "silent", source: source)!
        #expect(PracticeQueue.next(from: [silent], events: [], at: now).isEmpty)
    }
}
