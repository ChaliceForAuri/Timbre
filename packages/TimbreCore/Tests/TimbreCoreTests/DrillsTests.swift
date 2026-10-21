import Foundation
import Testing

@testable import TimbreCore

struct DrillsTests {

    @Test func theDrillsCorpusHolds() throws {
        let outcomes = try DrillCorpus.load(from: Fixtures.url("drills.json")).run()
        #expect(outcomes.count >= 12)
        for outcome in outcomes {
            #expect(
                outcome.held,
                "\(outcome.id): expected \(outcome.expected), got \(outcome.got) (\(outcome.detail))")
        }
    }

    @Test func sayItGuardrailNamesTheFirstProblem() {
        #expect(SayItGuardrail.failures(in: "  ", for: "tacit") == [.empty])
        #expect(
            SayItGuardrail.verdict(for: [.missingTerm], term: "tacit")?.reason
                == "The sentence has to use tacit.")
        #expect(SayItGuardrail.verdict(for: [], term: "tacit") == nil)
        let long = Array(repeating: "very", count: 45).joined(separator: " ") + " tacit."
        #expect(SayItGuardrail.failures(in: long, for: "tacit") == [.tooLong])
    }

    @Test func aJudgesVerdictIsBelievedOnlyInShape() {
        #expect(SayItGuardrail.accepts(DrillVerdict(passed: true, reason: "Used in its meaning.")))
        #expect(!SayItGuardrail.accepts(DrillVerdict(passed: true, reason: "")))
        let essay = Array(repeating: "because", count: 40).joined(separator: " ")
        #expect(!SayItGuardrail.accepts(DrillVerdict(passed: false, reason: essay)))
    }

    @Test func explainItKeyTermsDropStopwordsAndTheTermItself() {
        let terms = ExplainItCheck.keyTerms(
            of: "a record of an architecture decision", excluding: "decision record")
        #expect(terms == ["architecture"])
        #expect(
            ExplainItCheck.keyTerms(of: "Architecture Decision Record", excluding: "ADR") == [
                "architecture", "decision", "record",
            ])
    }

    @Test func streaksCountActiveDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        func day(_ d: Int, kind: LibraryEvent.Kind = .passed) -> LibraryEvent {
            LibraryEvent(
                entry: "word:x", kind: kind,
                date: calendar.date(from: DateComponents(year: 2026, month: 10, day: d, hour: 10))!,
                device: .mac,
                drill: kind == .met ? nil : .spellIt)
        }
        let events = [day(14), day(15, kind: .met), day(16), day(18), day(19), day(20, kind: .failed)]
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 15))!
        #expect(Streaks.current(in: events, on: today, calendar: calendar) == 3)
        #expect(Streaks.best(in: events, calendar: calendar) == 3)
        // Today empty, yesterday active: the streak is still alive.
        let tomorrow = calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 9))!
        #expect(Streaks.current(in: events, on: tomorrow, calendar: calendar) == 3)
        let later = calendar.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9))!
        #expect(Streaks.current(in: events, on: later, calendar: calendar) == 0)
        // A taught event is not activity.
        #expect(Streaks.current(in: [day(20, kind: .taught)], on: today, calendar: calendar) == 0)

        let week = Streaks.week(in: events, ending: today, calendar: calendar)
        #expect(week == Streaks.Week(met: 1, practised: 5, passed: 4, failed: 1))
    }

    @Test func weakestAreTheDueOnesFirst() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let source = Provenance(device: .mac, date: now, how: .typed)
        let old = LibraryEntry(kind: .word, term: "old", source: source)!
        let fresh = LibraryEntry(kind: .word, term: "fresh", source: source)!
        let events = [
            LibraryEvent(
                entry: old.id, kind: .taught, date: now.addingTimeInterval(-20 * 86400), device: .mac),
            LibraryEvent(entry: fresh.id, kind: .taught, date: now.addingTimeInterval(-3600), device: .mac),
        ]
        let weakest = Streaks.weakest(among: [fresh, old], events: events, at: now)
        #expect(weakest.map(\.entry.term) == ["old", "fresh"])
        #expect(weakest[0].strength < weakest[1].strength)
    }
}
