import Foundation

/// Today's word, written by the app for its widgets and complications to
/// read (GDR-0026, GDR-0027): the term, one line, whether it has been met,
/// and which day it is for. A widget never opens the Library; it reads
/// this, and shows nothing when the day has moved on.
nonisolated public struct TodaySnapshot: Codable, Equatable, Sendable {

    public let dayKey: String
    public let term: String
    public let summary: String
    public let why: String
    public let metToday: Bool

    public init(dayKey: String, term: String, summary: String, why: String, metToday: Bool) {
        self.dayKey = dayKey
        self.term = term
        self.summary = summary
        self.why = why
        self.metToday = metToday
    }

    public init(card: WordCard, on day: Date, calendar: Calendar = .current) {
        self.init(
            dayKey: Self.dayKey(for: day, calendar: calendar), term: card.term, summary: card.summary,
            why: card.why, metToday: card.metToday)
    }

    /// Whether this snapshot is for `day`.
    public func isFor(_ day: Date, calendar: Calendar = .current) -> Bool {
        dayKey == Self.dayKey(for: day, calendar: calendar)
    }

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public func write(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }

    public static func read(from url: URL) -> TodaySnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TodaySnapshot.self, from: data)
    }

    public static func remove(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
