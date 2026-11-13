import Foundation
import Testing

@testable import TimbreCore

struct StrengthTests {

    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func event(_ kind: LibraryEvent.Kind, daysLater: Double) -> LibraryEvent {
        LibraryEvent(
            entry: "word:x", kind: kind, date: start.addingTimeInterval(daysLater * 86400), device: .mac)
    }

    @Test func noHistoryIsZero() {
        #expect(Strength.strength(of: [], at: start) == 0)
        #expect(!Strength.isDue([], at: start))
    }

    @Test func aTaughtWordStartsFullAndIsNotYetDue() {
        let history = [event(.taught, daysLater: 0)]
        #expect(Strength.strength(of: history, at: start) == 1)
        #expect(!Strength.isDue(history, at: start.addingTimeInterval(86400)))
    }

    /// Stability is defined as the days until recall falls to the target.
    @Test func fadesToTheTargetAtStabilityDays() throws {
        let state = try #require(Strength.state(after: [event(.taught, daysLater: 0)]))
        let then = start.addingTimeInterval(state.stability * 86400)
        #expect(abs(Strength.retrievability(state, at: then) - Strength.targetRetention) < 1e-9)
        #expect(Strength.isDue([event(.taught, daysLater: 0)], at: then.addingTimeInterval(1)))
    }

    @Test func aPassRaisesStabilityAndAFailLowersIt() throws {
        let taught = try #require(Strength.state(after: [event(.taught, daysLater: 0)]))
        let passed = try #require(
            Strength.state(after: [event(.taught, daysLater: 0), event(.passed, daysLater: 3)]))
        let failed = try #require(
            Strength.state(after: [event(.taught, daysLater: 0), event(.failed, daysLater: 3)]))
        #expect(passed.stability > taught.stability)
        #expect(failed.stability < taught.stability)
        #expect(failed.difficulty > passed.difficulty)
    }

    /// Meeting the word in a dictation is as good as passing a drill.
    @Test func metCountsAsAPass() {
        let met = Strength.state(after: [event(.taught, daysLater: 0), event(.met, daysLater: 3)])
        let passed = Strength.state(after: [event(.taught, daysLater: 0), event(.passed, daysLater: 3)])
        #expect(met == passed)
    }

    @Test func aForgotEndsTheHistoryUntilTaughtAgain() {
        let forgotten = [event(.taught, daysLater: 0), event(.forgot, daysLater: 5)]
        #expect(Strength.strength(of: forgotten, at: start.addingTimeInterval(6 * 86400)) == 0)
        let again = forgotten + [event(.taught, daysLater: 7)]
        #expect(Strength.strength(of: again, at: start.addingTimeInterval(7 * 86400)) == 1)
    }

    @Test func replayDoesNotDependOnInputOrder() {
        let history = [
            event(.taught, daysLater: 0), event(.passed, daysLater: 2), event(.failed, daysLater: 9),
            event(.met, daysLater: 11),
        ]
        let shuffled = [history[3], history[0], history[2], history[1]]
        #expect(Strength.state(after: history) == Strength.state(after: shuffled))
    }

    @Test func difficultyStaysWithinOneAndTen() throws {
        var history = [event(.taught, daysLater: 0)]
        for day in 1...40 { history.append(event(.failed, daysLater: Double(day))) }
        let state = try #require(Strength.state(after: history))
        #expect(state.difficulty <= 10 && state.difficulty >= 1)
        #expect(state.stability >= 0.1)
    }
}
