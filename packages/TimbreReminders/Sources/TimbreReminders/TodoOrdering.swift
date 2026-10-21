import TimbreCore

/// How the list reads back (GDR-0016): soonest first, undated last, and
/// alphabetical among equals. Pure, so it is tested without Reminders.
nonisolated enum TodoOrdering {

    static func soonestFirst(_ todos: [Todo]) -> [Todo] {
        todos.sorted { a, b in
            switch (a.due, b.due) {
            case (let x?, let y?): return x < y || (x == y && a.title < b.title)
            case (nil, _?): return false
            case (_?, nil): return true
            default: return a.title < b.title
            }
        }
    }
}
