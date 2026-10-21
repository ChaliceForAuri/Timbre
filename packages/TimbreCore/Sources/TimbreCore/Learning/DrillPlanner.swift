import Foundation

/// Which drill an entry gets today (GDR-0023, decision 5): an acronym is
/// explained; a spelling is spelled; a word or phrase with a meaning
/// alternates between saying it and spelling it, by the day, so the same
/// word is not always asked the same way; one without a meaning can only
/// be spelled. Pure, so the plan is the same on every device.
nonisolated public enum DrillPlanner {

    public static func drill(for entry: LibraryEntry, on day: Date, calendar: Calendar = .current) -> Drill {
        switch entry.kind {
        case .acronym:
            return entry.meaning == nil ? .spellIt : .explainIt
        case .spelling, .correction:
            return .spellIt
        case .word, .phrase:
            guard entry.meaning != nil else { return .spellIt }
            let ordinal = calendar.ordinality(of: .day, in: .era, for: day) ?? 0
            let salt = entry.term.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            return (ordinal + salt) % 2 == 0 ? .sayIt : .spellIt
        }
    }

    /// The drills that can run where there is no model (GDR-0026): the
    /// ones a judge is not needed for.
    public static func drill(
        for entry: LibraryEntry, on day: Date, withModel: Bool, calendar: Calendar = .current
    ) -> Drill {
        let planned = drill(for: entry, on: day, calendar: calendar)
        if withModel { return planned }
        switch planned {
        case .sayIt: return .spellIt
        case .explainIt:
            return entry.meaning.map {
                ExplainItCheck.keyTerms(of: $0, excluding: entry.term).isEmpty ? .spellIt : .explainIt
            } ?? .spellIt
        case .spellIt: return .spellIt
        }
    }
}
