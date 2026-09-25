import Foundation

/// One spoken to-do, parsed (GDR-0016).
nonisolated public struct Todo: Equatable, Sendable {
    public let title: String
    /// When it is due, if a date was said.
    public let due: Date?
    /// Whether a time of day was said, not just a day. Decides whether the
    /// reminder gets an alarm.
    public let hasTime: Bool
}

/// Turns "remind me to call the dentist Thursday" into a title and a date —
/// deterministically, with Apple's data detector, no model. The date phrase
/// leaves the title along with the preposition that introduced it.
nonisolated enum TodoParser {

    /// Openers people say before the actual to-do.
    private static var openers: Regex<AnyRegexOutput> {
        try! Regex(
            #"^(?:(?:please |ok |okay |hey )?(?:remind me to|remember to|i need to|i have to|don't forget to|add (?:a )?(?:to-?do|task|reminder)(?: to)?|note to self|to-?do|todo|reminder)[:,]?\s+)"#
        ).ignoresCase()
    }

    /// A time of day was named, not just a day.
    private static var timeWords: Regex<AnyRegexOutput> {
        try! Regex(
            #"\d\s*[:.]\s*\d|\d\s*[ap]\.?m\b|\b(?:noon|midnight|midday|morning|afternoon|evening|tonight|o'?clock)\b"#
        ).ignoresCase()
    }

    static func parse(_ spoken: String, now: Date = Date()) -> Todo {
        var text = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacing(openers, with: "")

        var due: Date?
        var hasTime = false
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
            let match = detector.firstMatch(
                in: text, options: [], range: NSRange(text.startIndex..., in: text)),
            let date = match.date, let range = Range(match.range, in: text)
        {
            due = date
            let phrase = String(text[range])
            hasTime = phrase.contains(timeWords)
            // Remove the phrase and the little word before it: "on Thursday",
            // "by tomorrow", "at 3pm". Then whatever punctuation was left behind.
            let before = text[..<range.lowerBound]
            let after = text[range.upperBound...]
            let trimmedBefore = before.replacing(
                try! Regex(#"\s*\b(?:on|at|by|before|for|until|till|this|due)\s*$"#).ignoresCase(), with: ""
            )
            text = String(trimmedBefore) + " " + String(after)
        }

        var title = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        if title.isEmpty { title = spoken.trimmingCharacters(in: .whitespacesAndNewlines) }
        title = SentenceCapitalizer.capitalized(title)

        // A date with no time is a day; a due "12:00" from the detector is
        // its placeholder, not something the user said.
        if let date = due, !hasTime {
            due = Calendar.current.startOfDay(for: date)
        }
        return Todo(title: title, due: due, hasTime: hasTime)
    }
}

/// How to-dos are spoken back and shown in the pill.
nonisolated enum TodoPhrasing {

    static func confirmation(_ todo: Todo, list: String, now: Date = Date()) -> String {
        guard let due = todo.due else { return "Added to \(list): \(todo.title)" }
        return "Added to \(list): \(todo.title) · \(when(due, hasTime: todo.hasTime, now: now))"
    }

    /// "Thursday", "tomorrow at 3 PM", "14 Oct".
    static func when(_ date: Date, hasTime: Bool, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDate(date, inSameDayAs: now) {
            day = "today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
            calendar.isDate(date, inSameDayAs: tomorrow)
        {
            day = "tomorrow"
        } else if let week = calendar.date(byAdding: .day, value: 6, to: now), date < week, date > now {
            day = date.formatted(.dateTime.weekday(.wide))
        } else {
            day = date.formatted(.dateTime.day().month(.abbreviated))
        }
        return hasTime ? "\(day) at \(date.formatted(.dateTime.hour().minute()))" : day
    }

    /// The list, read aloud.
    static func spokenList(_ todos: [Todo], list: String, now: Date = Date()) -> String {
        guard !todos.isEmpty else { return "Your \(list) list is empty." }
        let count = todos.count == 1 ? "one to-do" : "\(todos.count) to-dos"
        let items = todos.map { todo -> String in
            guard let due = todo.due else { return todo.title }
            return "\(todo.title), \(when(due, hasTime: todo.hasTime, now: now))"
        }
        return "You have \(count). " + items.joined(separator: ". ") + "."
    }
}
