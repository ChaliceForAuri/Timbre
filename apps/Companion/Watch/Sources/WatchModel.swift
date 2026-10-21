import Foundation
import Observation
import TimbreCloud
import TimbreCore
import TimbreRelay
import TimbreReminders
import WatchKit
import WidgetKit

/// The wrist (GDR-0026): the to-do key, the word of the day at a glance,
/// Spell it, a word you heard. Nothing here needs the model; speech input
/// is the system's dictation, which hands back text.
@Observable
final class WatchModel {

    static let shared = WatchModel()

    let library: Library
    let reminders = ReminderStore()
    /// The Library through the user's own iCloud (GDR-0023 decision 1).
    let cloud: CloudKitLibrarySync
    /// Hands each to-do to the iPhone, which files it (GDR-0029).
    let relay = Relay(queueURL: SharedContainer.directory.appending(path: "pending-todos.json"))
    private(set) var card: WordCard?
    /// The last to-do the phone confirmed, for the screen.
    private(set) var lastFiled: String?

    private init() {
        library = Library(fileURL: SharedContainer.libraryURL, device: .watch, legacy: nil)
        cloud = CloudKitLibrarySync(
            library: library, stateURL: SharedContainer.directory.appending(path: "library-sync.json"))
        library.addSaveObserver { [weak self] in self?.refresh() }
        relay.onFiled = { [weak self] item, list in
            self?.lastFiled = TodoPhrasing.confirmation(item.todo, list: list)
            WKInterfaceDevice.current().play(.success)
        }
        relay.activate()
        if syncsThroughICloud { cloud.start() }
    }

    /// The toggle (GDR-0010): off by default.
    var syncsThroughICloud: Bool {
        get { UserDefaults.standard.bool(forKey: "librarySyncsThroughICloud") }
        set {
            UserDefaults.standard.set(newValue, forKey: "librarySyncsThroughICloud")
            if newValue { cloud.start() } else { cloud.stop() }
        }
    }

    func refresh() {
        let now = Date()
        guard let pick = library.wordOfTheDay(on: now) else {
            card = nil
            TodaySnapshot.remove(at: SharedContainer.snapshotURL)
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        var entry: LibraryEntry?
        var strength: Double?
        var metToday = false
        if case .library(let id, _) = pick.source {
            entry = library.entry(id)
            strength = library.strength(of: id, at: now)
            metToday = library.events.contains {
                $0.entry == id && $0.kind == .met && Calendar.current.isDate($0.date, inSameDayAs: now)
            }
        }
        let card = WordCard(pick: pick, entry: entry, metToday: metToday, strength: strength)
        self.card = card
        try? TodaySnapshot(card: card, on: now).write(to: SharedContainer.snapshotURL)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Say it: parsed here, filed by the iPhone, queued until it can be
    /// (GDR-0029). EventKit on the Watch reads but never writes.
    func addTodo(spoken: String) -> Todo {
        let todo = TodoParser.parse(spoken.trimmingCharacters(in: CharacterSet(charactersIn: ".!")))
        relay.send(todo)
        WKInterfaceDevice.current().play(.click)
        return todo
    }

    /// The list, read on the wrist.
    func openTodos() async throws -> (list: String, todos: [Todo]) {
        if reminders.authorization == .notDetermined {
            _ = await reminders.requestAccess()
        }
        return try await reminders.openTodos()
    }

    /// A word you heard, banked with provenance; the meaning fills in later.
    func addHeardWord(_ word: String) {
        library.add(word, how: .dictated, app: "Watch")
        WKInterfaceDevice.current().play(.click)
    }

    func spell(_ spoken: String, for entry: LibraryEntry) -> SpellVerdict {
        let verdict = SpellCheck.check(entry.term, against: spoken)
        library.record(verdict.passed ? .passed : .failed, for: entry.id, drill: .spellIt)
        WKInterfaceDevice.current().play(verdict.passed ? .success : .failure)
        return verdict
    }

    func practiceQueue() -> [LibraryEntry] {
        PracticeQueue.next(from: library.entries, events: library.events, at: Date(), limit: 5)
    }
}
