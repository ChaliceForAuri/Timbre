import EventKit
import Foundation

/// Timbre's to-dos live in Apple's Reminders (GDR-0016): it is already on
/// every device the user owns, it already syncs through their own iCloud,
/// and Timbre's binary still makes no network requests — the system does the
/// syncing, as GDR-0010 reasons for the dictionary.
///
/// Full access, because reading the list back needs it; write-only would
/// do for capture alone.
final class ReminderStore {

    static let defaultListTitle = "Timbre"
    private static let listKey = "todoListIdentifier"

    enum Failure: LocalizedError {
        case noAccess
        case noWritableSource
        case save(String)

        var errorDescription: String? {
            switch self {
            case .noAccess: "Timbre needs Reminders access — Settings › General."
            case .noWritableSource: "No Reminders account can take a new list."
            case .save(let why): "Couldn't save the reminder: \(why)"
            }
        }
    }

    /// A list the user can choose in Settings.
    struct List: Identifiable, Equatable {
        let id: String
        let title: String
        let account: String
    }

    private let store = EKEventStore()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var authorization: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    var hasAccess: Bool { authorization == .fullAccess }

    /// Prompts the user the first time; macOS remembers the answer.
    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToReminders()) ?? false
    }

    /// The list captures go to. Nil means "Timbre", created on first use.
    var chosenListIdentifier: String? {
        get { defaults.string(forKey: Self.listKey) }
        set { defaults.set(newValue, forKey: Self.listKey) }
    }

    var chosenListTitle: String {
        guard let id = chosenListIdentifier, let list = store.calendar(withIdentifier: id) else {
            return Self.defaultListTitle
        }
        return list.title
    }

    func lists() -> [List] {
        store.calendars(for: .reminder)
            .filter(\.allowsContentModifications)
            .map { List(id: $0.calendarIdentifier, title: $0.title, account: $0.source.title) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// The chosen list, or the "Timbre" list — found, or created in the
    /// account the user's default reminders live in.
    private func resolveList() throws -> EKCalendar {
        if let id = chosenListIdentifier, let list = store.calendar(withIdentifier: id) {
            return list
        }
        let existing = store.calendars(for: .reminder)
            .filter { $0.title == Self.defaultListTitle && $0.allowsContentModifications }
        if let list = existing.first { return list }

        let source =
            store.defaultCalendarForNewReminders()?.source
            ?? store.sources.first { $0.sourceType == .calDAV }
            ?? store.sources.first { $0.sourceType == .local }
        guard let source else { throw Failure.noWritableSource }

        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = Self.defaultListTitle
        list.source = source
        do {
            try store.saveCalendar(list, commit: true)
        } catch {
            throw Failure.save(error.localizedDescription)
        }
        return list
    }

    /// Saves one to-do. Returns the name of the list it went to.
    func add(_ todo: Todo) throws -> String {
        guard hasAccess else { throw Failure.noAccess }
        let list = try resolveList()

        let reminder = EKReminder(eventStore: store)
        reminder.calendar = list
        reminder.title = todo.title
        if let due = todo.due {
            let units: Set<Calendar.Component> =
                todo.hasTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
            reminder.dueDateComponents = Calendar.current.dateComponents(units, from: due)
            if todo.hasTime { reminder.addAlarm(EKAlarm(absoluteDate: due)) }
        }
        do {
            try store.save(reminder, commit: true)
        } catch {
            throw Failure.save(error.localizedDescription)
        }
        return list.title
    }

    /// Open to-dos in the chosen list, soonest first, undated last.
    func openTodos() async throws -> (list: String, todos: [Todo]) {
        guard hasAccess else { throw Failure.noAccess }
        let list = try resolveList()
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: [list])
        // Converted inside the callback: EKReminder is not Sendable, Todo is.
        let todos: [Todo] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let todos = (reminders ?? []).map { reminder -> Todo in
                    let components = reminder.dueDateComponents
                    let hasTime = components?.hour != nil
                    let due = components.flatMap { Calendar.current.date(from: $0) }
                    return Todo(title: reminder.title ?? "", due: due, hasTime: hasTime)
                }
                continuation.resume(returning: todos)
            }
        }
        .sorted { a, b in
            switch (a.due, b.due) {
            case (let x?, let y?): return x < y
            case (nil, _?): return false
            case (_?, nil): return true
            default: return a.title < b.title
            }
        }
        return (list.title, todos)
    }
}
