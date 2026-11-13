import Foundation

/// Today's word (GDR-0027): the weakest entry that is due, else a bundled
/// word for the profile. A deterministic function of the Library's state at
/// the start of the day and the date — the same word all day, on every
/// device, and in every test.
nonisolated public struct DailyPick: Equatable, Sendable {

    public enum Source: Equatable, Sendable {
        case library(entryID: String, strength: Double)
        case bundled(list: String, word: BundledWord)
    }

    public let term: String
    public let source: Source
    /// One line saying why this word today: which event earned it.
    public let why: String
}

nonisolated public enum DailyPicker {

    /// Events from `day` itself are ignored: yesterday's state chooses today's
    /// word, so a word taught at ten past nine does not change what the
    /// complication has shown since midnight.
    public static func pick(
        entries: [LibraryEntry],
        events: [LibraryEvent],
        profile: Profile,
        bundled: [BundledList],
        on day: Date,
        calendar: Calendar = .current
    ) -> DailyPick? {
        let start = calendar.startOfDay(for: day)
        let before = events.filter { $0.date < start }
        let byEntry = Dictionary(grouping: before, by: \.entry)

        var due: [(entry: LibraryEntry, strength: Double, last: LibraryEvent)] = []
        for entry in entries where entry.kind.isLearnable {
            guard let history = byEntry[entry.id], let last = LibraryEvent.ordered(history).last else {
                continue
            }
            guard Strength.isDue(history, at: start) else { continue }
            due.append((entry, Strength.strength(of: history, at: start), last))
        }
        if let weakest = due.min(by: {
            ($0.strength, $0.last.date, $0.entry.term) < ($1.strength, $1.last.date, $1.entry.term)
        }) {
            return DailyPick(
                term: weakest.entry.term,
                source: .library(entryID: weakest.entry.id, strength: weakest.strength),
                why: why(weakest.last, on: start, calendar: calendar)
            )
        }
        return bundledPick(
            entries: entries, profile: profile, bundled: bundled, on: start, calendar: calendar)
    }

    /// The profile's own lists, minus anything already in the Library, walked
    /// one word per day; the general lists only once those run out, so a
    /// reader with an industry meets their industry's words first.
    static func bundledPick(
        entries: [LibraryEntry], profile: Profile, bundled: [BundledList], on start: Date, calendar: Calendar
    ) -> DailyPick? {
        let known = Set(entries.map { LibraryEntry.normalized($0.term) })
        let industries = Set(profile.industries.map { $0.lowercased() })
        let mine = bundled.filter { !Set($0.industries.map { $0.lowercased() }).isDisjoint(with: industries) }
        let general = bundled.filter(\.industries.isEmpty)
        func unknown(in lists: [BundledList]) -> [(BundledList, BundledWord)] {
            lists.flatMap { list in
                list.words.filter { !known.contains(LibraryEntry.normalized($0.term)) }.map { (list, $0) }
            }
        }
        var candidates = unknown(in: mine)
        if candidates.isEmpty { candidates = unknown(in: general) }
        guard !candidates.isEmpty else { return nil }
        let epoch = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let dayNumber = calendar.dateComponents([.day], from: epoch, to: start).day ?? 0
        let (list, word) = candidates[((dayNumber % candidates.count) + candidates.count) % candidates.count]
        return DailyPick(
            term: word.term,
            source: .bundled(list: list.id, word: word),
            why: "From the \(list.title) list, for your profile."
        )
    }

    static func why(_ last: LibraryEvent, on start: Date, calendar: Calendar) -> String {
        let when = relative(last.date, from: start, calendar: calendar)
        switch last.kind {
        case .taught:
            return "You taught it \(when) and have not met it since."
        case .met:
            return "You last used it \(when); it is fading."
        case .passed:
            return "You last practised it \(when); it is fading."
        case .failed:
            return "You missed it in \(last.drill?.name ?? "practice") \(when)."
        case .forgot:
            return "It was forgotten \(when)."
        }
    }

    /// "yesterday", "on Tuesday", "on 3 Oct".
    static func relative(_ date: Date, from start: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: start).day ?? 0
        switch days {
        case 0: return "today"
        case 1: return "yesterday"
        case 2...6: return "on " + date.formatted(.dateTime.weekday(.wide))
        default: return "on " + date.formatted(.dateTime.day().month(.abbreviated))
        }
    }
}
