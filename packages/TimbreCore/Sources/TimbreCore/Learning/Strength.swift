import Foundation

/// Strength is retrievability: the probability of recalling an entry right
/// now, computed from its history alone (ADR-0014). The model is FSRS-4.5
/// with its published default parameters — three numbers per entry
/// (stability, difficulty, and the time since the last recall) and a power
/// law. Every outcome moves the curve; nothing is stored but the events.
///
/// Timbre's grades are coarse on purpose: a pass or a meeting in the wild is
/// "good", a fail is "again". No self-grading (GDR-0026's trap).
nonisolated public enum Strength {

    /// Below this an entry is due: its chance of recall has fallen too far.
    public static let targetRetention = 0.9

    public struct State: Equatable, Sendable {
        /// Days until retrievability falls to the target.
        public var stability: Double
        /// 1...10; how slowly stability grows for this entry.
        public var difficulty: Double
        public var lastReview: Date
    }

    enum Grade: Int {
        case again = 1
        case hard = 2
        case good = 3
        case easy = 4
    }

    // FSRS-4.5 default weights.
    static let weights: [Double] = [
        0.4072, 1.1829, 3.1262, 15.4722, 7.2102, 0.5316, 1.0651, 0.0234, 1.616, 0.1544, 1.0824, 1.9813,
        0.0953, 0.2975, 2.2042, 0.2407, 2.9466,
    ]
    static let decay = -0.5
    static let factor = 19.0 / 81.0

    // MARK: - The curve

    /// The chance of recall `days` after the last one. 1 at the moment of
    /// recall; the target at `stability` days, by definition.
    public static func retrievability(_ state: State, at date: Date) -> Double {
        let elapsed = max(0, days(from: state.lastReview, to: date))
        return curve(elapsed, stability: state.stability)
    }

    static func curve(_ elapsed: Double, stability: Double) -> Double {
        pow(1 + factor * elapsed / stability, decay)
    }

    /// The state after replaying a history in date order; nil when there is
    /// none, or the entry was forgotten and not taught again.
    public static func state(after history: [LibraryEvent]) -> State? {
        var state: State?
        for event in LibraryEvent.ordered(history) {
            switch event.kind {
            case .forgot:
                state = nil
            case .taught:
                // A first encounter. Teaching a word is producing it, so it
                // starts where a first "good" would. Re-teaching an entry
                // that already has a history changes nothing.
                if state == nil { state = initial(.good, at: event.date) }
            case .met, .passed, .failed:
                let grade: Grade = event.kind == .failed ? .again : .good
                guard let previous = state else {
                    state = initial(grade, at: event.date)
                    continue
                }
                state = next(previous, grade: grade, at: event.date)
            }
        }
        return state
    }

    /// 0 for an entry with no history.
    public static func strength(of history: [LibraryEvent], at date: Date) -> Double {
        guard let state = state(after: history) else { return 0 }
        return retrievability(state, at: date)
    }

    /// Has a history, and its chance of recall is below the target.
    public static func isDue(_ history: [LibraryEvent], at date: Date) -> Bool {
        guard let state = state(after: history) else { return false }
        return retrievability(state, at: date) < targetRetention
    }

    // MARK: - FSRS-4.5

    static func initial(_ grade: Grade, at date: Date) -> State {
        State(stability: initialStability(grade), difficulty: initialDifficulty(grade), lastReview: date)
    }

    static func initialStability(_ grade: Grade) -> Double {
        max(weights[grade.rawValue - 1], 0.1)
    }

    static func initialDifficulty(_ grade: Grade) -> Double {
        clampDifficulty(weights[4] - Double(grade.rawValue - 3) * weights[5])
    }

    static func next(_ state: State, grade: Grade, at date: Date) -> State {
        let elapsed = max(0, days(from: state.lastReview, to: date))
        let retrievability = curve(elapsed, stability: state.stability)
        let difficulty = nextDifficulty(state.difficulty, grade: grade)
        let stability =
            grade == .again
            ? forgetStability(state.difficulty, state.stability, retrievability)
            : recallStability(state.difficulty, state.stability, retrievability, grade: grade)
        return State(stability: max(stability, 0.1), difficulty: difficulty, lastReview: date)
    }

    static func nextDifficulty(_ difficulty: Double, grade: Grade) -> Double {
        let moved = difficulty - weights[6] * Double(grade.rawValue - 3)
        let reverted = weights[7] * initialDifficulty(.easy) + (1 - weights[7]) * moved
        return clampDifficulty(reverted)
    }

    static func recallStability(
        _ difficulty: Double, _ stability: Double, _ retrievability: Double, grade: Grade
    ) -> Double {
        let hardPenalty = grade == .hard ? weights[15] : 1
        let easyBonus = grade == .easy ? weights[16] : 1
        let growth =
            exp(weights[8]) * (11 - difficulty) * pow(stability, -weights[9])
            * (exp(weights[10] * (1 - retrievability)) - 1) * hardPenalty * easyBonus
        return stability * (growth + 1)
    }

    static func forgetStability(_ difficulty: Double, _ stability: Double, _ retrievability: Double) -> Double
    {
        weights[11] * pow(difficulty, -weights[12]) * (pow(stability + 1, weights[13]) - 1)
            * exp(weights[14] * (1 - retrievability))
    }

    static func clampDifficulty(_ value: Double) -> Double {
        min(max(value, 1), 10)
    }

    static func days(from start: Date, to end: Date) -> Double {
        end.timeIntervalSince(start) / 86400
    }
}
