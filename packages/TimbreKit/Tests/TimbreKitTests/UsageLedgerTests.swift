import Foundation
import Testing

@testable import TimbreKit

struct UsageLedgerTests {

    private let calendar = Calendar(identifier: .iso8601)
    private var monday: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 21))! }

    @Test func countsThisWeekAndAllTime() {
        var ledger = UsageLedger(now: monday, calendar: calendar)
        ledger.record(.dictation(words: 12), on: monday, calendar: calendar)
        ledger.record(.command, on: monday, calendar: calendar)
        ledger.record(.todo, on: monday, calendar: calendar)
        ledger.record(.reading, on: monday, calendar: calendar)
        #expect(ledger.thisWeek == ledger.allTime)
        #expect(
            ledger.allTime == UsageLedger.Counts(dictations: 1, words: 12, commands: 1, todos: 1, readings: 1)
        )
    }

    @Test func aNewWeekResetsThisWeekOnly() {
        var ledger = UsageLedger(now: monday, calendar: calendar)
        ledger.record(.dictation(words: 30), on: monday, calendar: calendar)
        let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)!
        ledger.record(.dictation(words: 5), on: nextMonday, calendar: calendar)
        #expect(ledger.thisWeek.words == 5)
        #expect(ledger.allTime.words == 35)
        #expect(ledger.weekStart == nextMonday)
    }

    @Test func countsWords() {
        #expect(UsageLedger.wordCount(of: "So I was thinking that we should ship it on Friday.") == 11)
        #expect(UsageLedger.wordCount(of: "  \n ") == 0)
    }

    @Test func persistsAndResets() {
        let suiteName = "TimbreKitTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        UsageStore(defaults: defaults).record(.todo)
        let reloaded = UsageStore(defaults: defaults)
        #expect(reloaded.ledger.allTime.todos == 1)
        reloaded.reset()
        #expect(UsageStore(defaults: defaults).ledger.allTime.isEmpty)
    }
}
