import Foundation

/// The spoken drills (GDR-0023, decision 5).
nonisolated public enum Drill: String, Codable, Sendable, CaseIterable {
    case spellIt
    case sayIt
    case explainIt

    public var name: String {
        switch self {
        case .spellIt: "Spell it"
        case .sayIt: "Say it"
        case .explainIt: "Explain it"
        }
    }
}

/// One thing that happened to an entry. The Library stores these and derives
/// strength from them (ADR-0014): the history is the record, the number
/// falls out. Events are immutable and only ever added, which is what lets
/// two devices merge by union (GDR-0023, decision 1).
nonisolated public struct LibraryEvent: Codable, Sendable, Hashable, Identifiable {

    public enum Kind: String, Codable, Sendable {
        /// The entry was added, by hand or from use.
        case taught
        /// Today's word turned up in a dictation. Only the fact and the app;
        /// never the sentence (GDR-0027).
        case met
        case passed
        case failed
        /// A tombstone: the entry was removed. It outlives the entry so a
        /// removal survives a sync race.
        case forgot
    }

    public let entry: String
    public let kind: Kind
    /// Whole seconds, so the id survives a round trip through JSON.
    public let date: Date
    public let device: Device
    public let app: String?
    public let drill: Drill?

    /// Composed, not hashed: unique for one thing happening once, and the
    /// same on every device that learns of it.
    public var id: String {
        [
            kind.rawValue, entry, String(Int(date.timeIntervalSince1970)), device.rawValue,
            drill?.rawValue ?? "", app ?? "",
        ]
        .joined(separator: "|")
    }

    public init(
        entry: String, kind: Kind, date: Date, device: Device, app: String? = nil, drill: Drill? = nil
    ) {
        self.entry = entry
        self.kind = kind
        self.date = Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
        self.device = device
        self.app = app
        self.drill = drill
    }

    /// Date order, ties broken by id, so a replay is the same everywhere.
    static func ordered(_ events: some Sequence<LibraryEvent>) -> [LibraryEvent] {
        events.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }
}

/// How two copies of a Library become one (GDR-0023, decision 1). Events
/// union; entries take the latest edit; a tombstone later than an entry's
/// last edit removes it. Pure, so it is tested without a server.
nonisolated public enum LibraryMerge {

    public static func events(_ local: [LibraryEvent], _ remote: [LibraryEvent]) -> [LibraryEvent] {
        var seen: Set<String> = []
        var union: [LibraryEvent] = []
        for event in local + remote where seen.insert(event.id).inserted {
            union.append(event)
        }
        return LibraryEvent.ordered(union)
    }

    /// Local order is kept; entries only the remote knows are appended in its
    /// order. For an id both hold, the later `edited` wins.
    public static func entries(
        _ local: [LibraryEntry], _ remote: [LibraryEntry], events: [LibraryEvent]
    ) -> [LibraryEntry] {
        var byID: [String: LibraryEntry] = [:]
        var order: [String] = []
        for entry in local + remote {
            if let existing = byID[entry.id] {
                if entry.edited > existing.edited { byID[entry.id] = entry }
            } else {
                byID[entry.id] = entry
                order.append(entry.id)
            }
        }
        let forgotten = Dictionary(
            events.filter { $0.kind == .forgot }.map { ($0.entry, $0.date) }, uniquingKeysWith: max)
        return order.compactMap { id in
            guard let entry = byID[id] else { return nil }
            if let forgotAt = forgotten[id], forgotAt >= entry.edited { return nil }
            return entry
        }
    }
}
