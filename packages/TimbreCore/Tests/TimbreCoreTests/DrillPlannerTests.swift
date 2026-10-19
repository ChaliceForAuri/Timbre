import Foundation
import Testing

@testable import TimbreCore

struct DrillPlannerTests {

    private let source = Provenance(device: .mac, date: Date(timeIntervalSince1970: 1_000_000), how: .typed)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test func kindsDecideTheDrill() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let acronym = LibraryEntry(
            kind: .acronym, term: "ADR", meaning: "Architecture Decision Record", source: source)!
        let spelling = LibraryEntry(kind: .spelling, term: "definitely", heard: "definately", source: source)!
        let bare = LibraryEntry(kind: .word, term: "tacit", source: source)!
        #expect(DrillPlanner.drill(for: acronym, on: day, calendar: calendar) == .explainIt)
        #expect(DrillPlanner.drill(for: spelling, on: day, calendar: calendar) == .spellIt)
        #expect(DrillPlanner.drill(for: bare, on: day, calendar: calendar) == .spellIt)
    }

    @Test func aWordWithAMeaningAlternatesByTheDay() {
        let word = LibraryEntry(kind: .word, term: "ephemeral", meaning: "short-lived", source: source)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20))!
        let next = calendar.date(byAdding: .day, value: 1, to: day)!
        let today = DrillPlanner.drill(for: word, on: day, calendar: calendar)
        let tomorrow = DrillPlanner.drill(for: word, on: next, calendar: calendar)
        #expect(today != tomorrow)
        #expect([today, tomorrow].allSatisfy { $0 == .sayIt || $0 == .spellIt })
        #expect(DrillPlanner.drill(for: word, on: day, calendar: calendar) == today)
    }

    @Test func withoutTheModelNothingNeedsAJudge() {
        let word = LibraryEntry(kind: .word, term: "ephemeral", meaning: "short-lived", source: source)!
        let acronym = LibraryEntry(
            kind: .acronym, term: "ADR", meaning: "Architecture Decision Record", source: source)!
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        for offset in 0..<4 {
            let on = day.addingTimeInterval(Double(offset) * 86400)
            #expect(DrillPlanner.drill(for: word, on: on, withModel: false, calendar: calendar) == .spellIt)
        }
        #expect(DrillPlanner.drill(for: acronym, on: day, withModel: false, calendar: calendar) == .explainIt)
    }
}
