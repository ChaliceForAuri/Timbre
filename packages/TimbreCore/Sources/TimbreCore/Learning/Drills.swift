import Foundation

/// A drill's outcome (GDR-0023, decision 5): pass or fail, and one line
/// saying why, in the shape every judge must return.
nonisolated public struct DrillVerdict: Equatable, Sendable, Codable {
    public let passed: Bool
    public let reason: String

    public init(passed: Bool, reason: String) {
        self.passed = passed
        self.reason = reason
    }
}

/// The model's half of a drill, where the model is (ADR-0015). Nil when it
/// cannot answer: the drill is then unavailable, never faked.
public protocol DrillJudge: Sendable {
    func judgeSayIt(term: String, meaning: String?, sentence: String) async -> DrillVerdict?
    func judgeExplainIt(term: String, meaning: String, explanation: String) async -> DrillVerdict?
}

/// Say it's guardrail: what must be true of the sentence before the model
/// is asked, and of the model's verdict before it is believed. The model
/// judges meaning; everything checkable without it is checked here.
nonisolated public enum SayItGuardrail {

    public enum Failure: String, Sendable, CaseIterable {
        case empty
        case missingTerm
        case tooShort
        case tooLong
        case tooManySentences
    }

    public static let minimumWords = 5
    public static let maximumWords = 40

    /// Why the sentence cannot be judged; empty when it can.
    public static func failures(in sentence: String, for term: String) -> [Failure] {
        let text = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [.empty] }
        var failures: [Failure] = []
        if !MetDetector.contains(term, in: text) { failures.append(.missingTerm) }
        let words = text.split(whereSeparator: \.isWhitespace).count
        if words < minimumWords { failures.append(.tooShort) }
        if words > maximumWords { failures.append(.tooLong) }
        if text.filter({ ".!?".contains($0) }).count > 2 { failures.append(.tooManySentences) }
        return failures
    }

    /// The sentence failed before the model was asked: the verdict says so.
    public static func verdict(for failures: [Failure], term: String) -> DrillVerdict? {
        guard let first = failures.first else { return nil }
        switch first {
        case .empty: return DrillVerdict(passed: false, reason: "Nothing heard.")
        case .missingTerm: return DrillVerdict(passed: false, reason: "The sentence has to use \(term).")
        case .tooShort: return DrillVerdict(passed: false, reason: "A few more words: a whole sentence.")
        case .tooLong: return DrillVerdict(passed: false, reason: "One sentence is enough.")
        case .tooManySentences:
            return DrillVerdict(passed: false, reason: "One or two sentences, not a paragraph.")
        }
    }

    /// A verdict the model returned is believed only in this shape.
    public static func accepts(_ verdict: DrillVerdict) -> Bool {
        let words = verdict.reason.split(whereSeparator: \.isWhitespace).count
        return (1...30).contains(words)
    }
}

/// Explain it's check (GDR-0023, decision 5): the key terms of the stored
/// meaning against what was said. Deterministic first; the model is asked
/// only in the band where the words alone cannot tell.
nonisolated public enum ExplainItCheck {

    public enum Outcome: Equatable, Sendable {
        case passed(DrillVerdict)
        case failed(DrillVerdict)
        /// The words half match: a judge should decide.
        case unsure(coverage: Double)
    }

    public static let passBand = 0.6
    public static let failBand = 0.25

    public static func check(term: String, meaning: String, explanation: String) -> Outcome {
        let wanted = keyTerms(of: meaning, excluding: term)
        let said = Set(tokens(of: explanation))
        guard !wanted.isEmpty else {
            // A one-word meaning: it is either said or not.
            let whole = MetDetector.contains(meaning, in: explanation)
            return whole
                ? .passed(DrillVerdict(passed: true, reason: "That is it."))
                : .failed(DrillVerdict(passed: false, reason: "It means: \(meaning)"))
        }
        let hits = wanted.filter { want in said.contains { stem($0) == stem(want) } }
        let coverage = Double(hits.count) / Double(wanted.count)
        if coverage >= passBand {
            return .passed(
                DrillVerdict(passed: true, reason: "You had it: \(hits.sorted().joined(separator: ", "))."))
        }
        if coverage < failBand || explanation.trimmingCharacters(in: .whitespaces).isEmpty {
            return .failed(DrillVerdict(passed: false, reason: "It means: \(meaning)"))
        }
        return .unsure(coverage: coverage)
    }

    /// The meaning's words that carry it: no stopwords, no repeat of the
    /// term itself, nothing shorter than three letters.
    static func keyTerms(of meaning: String, excluding term: String) -> [String] {
        let termTokens = Set(tokens(of: term))
        var seen: Set<String> = []
        return tokens(of: meaning).filter { token in
            token.count >= 3 && !stopwords.contains(token) && !termTokens.contains(token)
                && seen.insert(token).inserted
        }
    }

    static func tokens(of text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && !$0.isNumber && $0 != "-" }
            .map(String.init)
    }

    /// Five letters is enough to let "records" meet "recording".
    static func stem(_ word: String) -> String {
        String(word.prefix(5))
    }

    static let stopwords: Set<String> = [
        "the", "and", "for", "that", "with", "this", "from", "into", "are", "was", "were", "has", "have",
        "had",
        "not", "but", "its", "it's", "you", "your", "they", "their", "than", "then", "when", "which", "who",
        "what", "where", "how", "one", "very", "also", "can", "may", "being", "been", "used", "use",
        "something",
        "someone", "thing", "things", "about", "over", "under", "between", "without", "within", "such",
        "some",
        "any", "all", "each", "other", "more", "most", "less", "much", "many",
    ]
}

/// Streaks and the week (GDR-0027): the private kind of game. Days count
/// when a word was met or a drill was answered; nothing is ranked.
nonisolated public enum Streaks {

    public struct Week: Equatable, Sendable {
        public let met: Int
        public let practised: Int
        public let passed: Int
        public let failed: Int
    }

    /// Consecutive days up to and including `day` (or yesterday, if today
    /// is still empty) with a met or a drill.
    public static func current(in events: [LibraryEvent], on day: Date, calendar: Calendar = .current) -> Int
    {
        let days = activeDays(in: events, calendar: calendar)
        guard !days.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: day)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                days.contains(yesterday)
            else {
                return 0
            }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    public static func best(in events: [LibraryEvent], calendar: Calendar = .current) -> Int {
        let days = activeDays(in: events, calendar: calendar).sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for day in days {
            if let previous, let next = calendar.date(byAdding: .day, value: 1, to: previous), next == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    /// The seven days ending on `day`.
    public static func week(in events: [LibraryEvent], ending day: Date, calendar: Calendar = .current)
        -> Week
    {
        let end = calendar.startOfDay(for: day).addingTimeInterval(86400)
        let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
        let recent = events.filter { $0.date >= start && $0.date < end }
        let passed = recent.filter { $0.kind == .passed }.count
        let failed = recent.filter { $0.kind == .failed }.count
        return Week(
            met: recent.filter { $0.kind == .met }.count, practised: passed + failed, passed: passed,
            failed: failed)
    }

    /// The entries most worth a minute: due, weakest first, at most `limit`.
    public static func weakest(
        among entries: [LibraryEntry], events: [LibraryEvent], at date: Date, limit: Int = 5
    ) -> [(entry: LibraryEntry, strength: Double)] {
        let byEntry = Dictionary(grouping: events, by: \.entry)
        return entries.filter(\.kind.isLearnable)
            .compactMap { entry -> (LibraryEntry, Double)? in
                guard let history = byEntry[entry.id], !history.isEmpty else { return nil }
                return (entry, Strength.strength(of: history, at: date))
            }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map { (entry: $0.0, strength: $0.1) }
    }

    static func activeDays(in events: [LibraryEvent], calendar: Calendar) -> Set<Date> {
        Set(
            events.filter { $0.kind == .met || $0.kind == .passed || $0.kind == .failed }
                .map { calendar.startOfDay(for: $0.date) })
    }
}
