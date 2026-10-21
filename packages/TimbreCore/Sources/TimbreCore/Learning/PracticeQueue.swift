import Foundation

/// What to practise next (GDR-0023, decision 5): the learnable entries that
/// are due, weakest first; then, so a fresh Library still has something to
/// do, the most recently taught. Corrections are never drilled.
nonisolated public enum PracticeQueue {

    public static func next(
        from entries: [LibraryEntry], events: [LibraryEvent], at date: Date, limit: Int = 10
    ) -> [LibraryEntry] {
        let byEntry = Dictionary(grouping: events, by: \.entry)
        let learnable = entries.filter(\.kind.isLearnable)
        var due: [(entry: LibraryEntry, strength: Double)] = []
        var fresh: [(entry: LibraryEntry, taught: Date)] = []
        for entry in learnable {
            let history = byEntry[entry.id] ?? []
            if Strength.isDue(history, at: date) {
                due.append((entry, Strength.strength(of: history, at: date)))
            } else if let last = LibraryEvent.ordered(history).last {
                fresh.append((entry, last.date))
            }
        }
        let ordered =
            due.sorted { ($0.strength, $0.entry.term) < ($1.strength, $1.entry.term) }.map(\.entry)
            + fresh.sorted { ($0.taught, $0.entry.term) > ($1.taught, $1.entry.term) }.map(\.entry)
        return Array(ordered.prefix(limit))
    }
}
