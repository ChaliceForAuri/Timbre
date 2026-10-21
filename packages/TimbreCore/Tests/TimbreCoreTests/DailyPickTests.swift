import Foundation
import Testing

@testable import TimbreCore

struct DailyPickTests {

    @Test func theCorpusHolds() throws {
        let outcomes = try PickCorpus.load(from: Fixtures.url("picks.json")).run()
        #expect(outcomes.count >= 8)
        for outcome in outcomes {
            #expect(
                outcome.held,
                "\(outcome.id): expected \(outcome.expect.source) \(outcome.expect.term ?? ""), got \(outcome.pick?.term ?? "nothing")"
            )
        }
    }

    @Test func aBundledListIsWalkedOneWordPerDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let list = BundledList(
            id: "general", title: "General English",
            words: ["ephemeral", "tacit", "perfunctory"].map { BundledWord(term: $0, definition: "…") })
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20))!
        let picks = (0..<4).map { offset in
            DailyPicker.pick(
                entries: [], events: [], profile: .empty, bundled: [list],
                on: day.addingTimeInterval(Double(offset) * 86400), calendar: calendar)?.term
        }
        #expect(Set(picks.prefix(3).compactMap { $0 }).count == 3)
        #expect(picks[0] == picks[3])
    }

    @Test func theSameDayPicksTheSameWordAllDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let list = BundledList(
            id: "g", title: "General", words: [BundledWord(term: "tacit", definition: "…")])
        let morning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 8))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 23))!
        let a = DailyPicker.pick(
            entries: [], events: [], profile: .empty, bundled: [list], on: morning, calendar: calendar)
        let b = DailyPicker.pick(
            entries: [], events: [], profile: .empty, bundled: [list], on: evening, calendar: calendar)
        #expect(a == b)
        #expect(a?.why == "From the General list, for your profile.")
    }
}
