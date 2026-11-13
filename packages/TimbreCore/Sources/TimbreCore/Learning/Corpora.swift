import Foundation

/// Spell it's corpus (GDR-0023, decision 5): a word, what the recogniser
/// returned, and whether that spelling should pass. Run by the tests and by
/// `timbre-eval --spell`.
nonisolated public struct SpellCorpus: Codable, Sendable {

    public struct Case: Codable, Sendable {
        public let id: String
        public let note: String?
        public let word: String
        public let spoken: String
        public let passes: Bool
    }

    public struct Outcome: Sendable {
        public let id: String
        public let verdict: SpellVerdict
        public let expectedToPass: Bool
        public var held: Bool { verdict.passed == expectedToPass }
    }

    public let cases: [Case]

    public static func load(from url: URL) throws -> SpellCorpus {
        try JSONDecoder().decode(SpellCorpus.self, from: Data(contentsOf: url))
    }

    public func run() -> [Outcome] {
        cases.map {
            Outcome(
                id: $0.id, verdict: SpellCheck.check($0.word, against: $0.spoken), expectedToPass: $0.passes)
        }
    }
}

/// The word of the day's corpus (GDR-0027): a Library's state and a date in,
/// the expected pick out. Run by the tests and by `timbre-eval --picks`.
nonisolated public struct PickCorpus: Codable, Sendable {

    public struct Expectation: Codable, Sendable {
        /// "library", "bundled" or "none".
        public let source: String
        public let term: String?
    }

    public struct Case: Codable, Sendable {
        public let id: String
        public let note: String?
        /// "yyyy-MM-dd", in `timeZone` (UTC when absent).
        public let day: String
        public let timeZone: String?
        public let profile: Profile?
        public let entries: [LibraryEntry]
        public let events: [LibraryEvent]
        public let bundled: [BundledList]?
        public let expect: Expectation
    }

    public struct Outcome: Sendable {
        public let id: String
        public let pick: DailyPick?
        public let expect: Expectation
        public var held: Bool {
            switch (pick?.source, expect.source) {
            case (nil, "none"): return true
            case (.library?, "library"), (.bundled?, "bundled"):
                return expect.term == nil || expect.term == pick?.term
            default: return false
            }
        }
    }

    public let cases: [Case]

    public static func load(from url: URL) throws -> PickCorpus {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PickCorpus.self, from: Data(contentsOf: url))
    }

    public func run() -> [Outcome] {
        cases.map { testCase in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone =
                testCase.timeZone.flatMap(TimeZone.init(identifier:)) ?? TimeZone(identifier: "UTC")!
            let parts = testCase.day.split(separator: "-").compactMap { Int($0) }
            let day =
                calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
                ?? Date.distantPast
            let pick = DailyPicker.pick(
                entries: testCase.entries, events: testCase.events, profile: testCase.profile ?? .empty,
                bundled: testCase.bundled ?? [], on: day, calendar: calendar)
            return Outcome(id: testCase.id, pick: pick, expect: testCase.expect)
        }
    }
}
