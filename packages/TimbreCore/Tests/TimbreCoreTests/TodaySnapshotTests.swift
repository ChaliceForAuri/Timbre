import Foundation
import Testing

@testable import TimbreCore

struct TodaySnapshotTests {

    @Test func roundTripsThroughTheFile() throws {
        let directory = URL(filePath: NSTemporaryDirectory()).appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "today.json")
        let snapshot = TodaySnapshot(
            dayKey: "2026-10-20", term: "tacit", summary: "tacit — unspoken", why: "why", metToday: true)
        try snapshot.write(to: url)
        #expect(TodaySnapshot.read(from: url) == snapshot)
        TodaySnapshot.remove(at: url)
        #expect(TodaySnapshot.read(from: url) == nil)
    }

    @Test func knowsWhichDayItIsFor() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 15))!
        let card = WordCard(
            pick: DailyPick(
                term: "tacit",
                source: .bundled(list: "g", word: BundledWord(term: "tacit", definition: "unspoken")),
                why: "From the list."),
            entry: nil)
        let snapshot = TodaySnapshot(card: card, on: day, calendar: calendar)
        #expect(snapshot.dayKey == "2026-10-20")
        #expect(snapshot.summary == "tacit — unspoken")
        #expect(snapshot.isFor(day, calendar: calendar))
        #expect(!snapshot.isFor(day.addingTimeInterval(86400), calendar: calendar))
    }
}
