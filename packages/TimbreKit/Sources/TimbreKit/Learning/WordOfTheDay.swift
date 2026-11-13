import Foundation
import Observation
import TimbreCore
import TimbreModel
import TimbreSpeech

/// Today's word on the Mac (GDR-0027): the pick, the card with its labelled
/// facts, the menu bar line, the morning notification, and reading it
/// aloud. Rebuilt whenever the Library changes and when the day does.
@Observable
public final class WordOfTheDay {

    public enum NotificationState: Equatable, Sendable {
        case off
        case needsPermission
        case on
        case denied
    }

    public private(set) var card: WordCard?
    public private(set) var notificationState: NotificationState = .off

    /// Off by default (GDR-0027 inherits GDR-0013's manners): nothing
    /// appears until asked for.
    public var notifies: Bool {
        didSet {
            defaults.set(notifies, forKey: Keys.notifies)
            Task { await reschedule() }
        }
    }
    public var notificationHour: Int {
        didSet {
            defaults.set(notificationHour, forKey: Keys.hour)
            Task { await reschedule() }
        }
    }
    public var notificationMinute: Int {
        didSet {
            defaults.set(notificationMinute, forKey: Keys.minute)
            Task { await reschedule() }
        }
    }

    /// The app sets this to open the card window; the notification's tap
    /// calls it.
    public var onOpenCard: (@MainActor () -> Void)? {
        get { notifier.onOpen }
        set { notifier.onOpen = newValue }
    }

    private enum Keys {
        static let notifies = "wordOfTheDayNotifies"
        static let hour = "wordOfTheDayHour"
        static let minute = "wordOfTheDayMinute"
        static let example = "wordOfTheDayExample"
    }

    private let library: Library
    private let speech: SpeechReader
    private let writer = ExampleWriter()
    private let notifier = WordNotifier()
    private let defaults: UserDefaults
    private var refreshTask: Task<Void, Never>?
    private var midnightTask: Task<Void, Never>?

    init(library: Library, speech: SpeechReader, defaults: UserDefaults = .standard) {
        self.library = library
        self.speech = speech
        self.defaults = defaults
        notifies = defaults.bool(forKey: Keys.notifies)
        notificationHour = defaults.object(forKey: Keys.hour) as? Int ?? 9
        notificationMinute = defaults.object(forKey: Keys.minute) as? Int ?? 0
    }

    /// The Library changed, or the day did: rebuild the card and the
    /// pending notification. Coalesced; the last call wins.
    public func refresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            await rebuild()
            guard !Task.isCancelled else { return }
            await reschedule()
            waitForMidnight()
        }
    }

    public func requestNotifications() async {
        _ = await notifier.requestAuthorization()
        notifies = true
    }

    /// The card, read in the chosen voice (GDR-0008).
    public func read() {
        guard let card else { return }
        var text = card.term
        if let meaning = card.meanings.first { text += ". " + meaning.text }
        if let example = card.example { text += ". " + example.text }
        speech.read(text)
    }

    // MARK: - The card

    private func rebuild() async {
        let now = Date()
        guard let pick = library.wordOfTheDay(on: now, bundled: BundledLists.all) else {
            card = nil
            return
        }
        var entry: LibraryEntry?
        var strength: Double?
        var metToday = false
        var apple: (text: String, pronunciation: String?)?
        if case .library(let id, _) = pick.source {
            entry = library.entry(id)
            strength = library.strength(of: id, at: now)
            metToday = library.events.contains {
                $0.entry == id && $0.kind == .met && Calendar.current.isDate($0.date, inSameDayAs: now)
            }
            if let found = AppleDictionary.lookup(pick.term) { apple = (found.text, found.pronunciation) }
        }
        let example = await example(for: pick, entry: entry, on: now)
        guard !Task.isCancelled else { return }
        card = WordCard(
            pick: pick, entry: entry, appleDefinition: apple, example: example, metToday: metToday,
            strength: strength)
    }

    /// One example per word per day, kept in preferences, so the card reads
    /// the same every time it is opened. The user's own example wins and
    /// needs no model.
    private func example(for pick: DailyPick, entry: LibraryEntry?, on day: Date) async -> String? {
        if entry?.example != nil { return nil }
        let key = Self.dayKey(day) + "|" + pick.term
        if let kept = defaults.dictionary(forKey: Keys.example) as? [String: String], let text = kept[key] {
            return text
        }
        let meaning: String? = {
            if let own = entry?.meaning { return own }
            if case .bundled(_, let word) = pick.source { return word.definition }
            return nil
        }()
        let written = await writer.write(
            for: pick.term, meaning: meaning, industry: library.profile.industries.first)
        if let written { defaults.set([key: written], forKey: Keys.example) }
        return written
    }

    // MARK: - The notification

    private func reschedule() async {
        guard notifies else {
            notifier.cancel()
            notificationState = .off
            return
        }
        switch await notifier.authorization() {
        case .denied:
            notificationState = .denied
            notifier.cancel()
            return
        case .notAsked:
            notificationState = .needsPermission
            notifier.cancel()
            return
        case .granted:
            notificationState = .on
        }
        let fire = NotificationPlan.nextFire(
            hour: notificationHour, minute: notificationMinute, after: Date())
        guard let pick = library.wordOfTheDay(on: fire, bundled: BundledLists.all) else {
            notifier.cancel()
            return
        }
        var entry: LibraryEntry?
        if case .library(let id, _) = pick.source { entry = library.entry(id) }
        notifier.schedule(
            title: "Word of the day", body: WordCard(pick: pick, entry: entry).summary, at: fire)
    }

    private func waitForMidnight() {
        midnightTask?.cancel()
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
        else {
            return
        }
        midnightTask = Task {
            try? await Task.sleep(for: .seconds(max(1, tomorrow.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            refresh()
        }
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
