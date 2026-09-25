import Foundation

/// What Timbre has done for its user, counted on this Mac and nowhere else.
/// Pure: the store below persists it, the controller feeds it.
nonisolated public struct UsageLedger: Codable, Equatable, Sendable {

    public struct Counts: Codable, Equatable, Sendable {
        public var dictations = 0
        public var words = 0
        public var commands = 0
        public var todos = 0
        public var readings = 0

        public var isEmpty: Bool { dictations + words + commands + todos + readings == 0 }
    }

    public enum Event: Sendable, Equatable {
        case dictation(words: Int)
        case command
        case todo
        case reading
    }

    public private(set) var allTime = Counts()
    public private(set) var thisWeek = Counts()
    /// Start of the week `thisWeek` counts; a new week resets it.
    public private(set) var weekStart: Date

    public init(now: Date = Date(), calendar: Calendar = .current) {
        weekStart = Self.startOfWeek(containing: now, calendar: calendar)
    }

    public mutating func record(_ event: Event, on date: Date = Date(), calendar: Calendar = .current) {
        let week = Self.startOfWeek(containing: date, calendar: calendar)
        if week != weekStart {
            weekStart = week
            thisWeek = Counts()
        }
        Self.apply(event, to: &allTime)
        Self.apply(event, to: &thisWeek)
    }

    private static func apply(_ event: Event, to counts: inout Counts) {
        switch event {
        case .dictation(let words):
            counts.dictations += 1
            counts.words += max(words, 0)
        case .command: counts.commands += 1
        case .todo: counts.todos += 1
        case .reading: counts.readings += 1
        }
    }

    static func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// How many words a pasted text counts as.
    public static func wordCount(of text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}

/// Persists the ledger in `UserDefaults`, this Mac only, never transmitted.
@Observable
final class UsageStore {

    private static let key = "usageLedger"
    private let defaults: UserDefaults

    private(set) var ledger: UsageLedger {
        didSet { defaults.set(try? JSONEncoder().encode(ledger), forKey: Self.key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ledger =
            defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(UsageLedger.self, from: $0) }
            ?? UsageLedger()
    }

    func record(_ event: UsageLedger.Event) {
        ledger.record(event)
    }

    func reset() {
        ledger = UsageLedger()
    }
}
