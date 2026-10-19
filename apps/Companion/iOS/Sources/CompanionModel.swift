import AVFAudio
import Foundation
import Observation
import TimbreCloud
import TimbreCore
import TimbreModel
import TimbreRelay
import TimbreReminders
import TimbreSpeech
import WidgetKit

/// The iPhone's one coordinator (GDR-0023, decision 2): the Library in the
/// shared container, today's card, the spoken input for drills and to-dos,
/// the Timbre list, and the snapshot the widgets read. A companion, not a
/// port — nothing here dictates into another app.
@Observable
final class CompanionModel {

    /// One instance for the app and its App Intents, so a word added by
    /// Siri is in the list the screen is showing.
    static let shared = CompanionModel()

    let library: Library
    let reminders = ReminderStore()
    let reader = SpeechReader()
    /// The Library through the user's own iCloud (GDR-0023 decision 1, ADR-0017).
    let cloud: CloudKitLibrarySync
    /// Files the to-dos the Watch says (GDR-0029).
    private let relay = Relay(queueURL: SharedContainer.directory.appending(path: "pending-todos.json"))
    private let speech = SpokenInput()
    private let writer = ExampleWriter()
    private let judge = ModelDrillJudge()

    private(set) var card: WordCard?
    private(set) var isListening = false
    private(set) var speechReady = false
    let modelAvailability = OnDeviceModel.availability

    private var refreshTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard

    private init() {
        library = Library(fileURL: SharedContainer.libraryURL, device: .iPhone, legacy: nil)
        cloud = CloudKitLibrarySync(
            library: library, stateURL: SharedContainer.directory.appending(path: "library-sync.json"))
        library.addSaveObserver { [weak self] in self?.refresh() }
        relay.onTodo = { [weak self] todo in
            guard let self else { throw ReminderStore.Failure.noAccess }
            return try await self.file(todo)
        }
    }

    /// At launch: the card, the Watch's relay, the speech model's assets,
    /// the voice.
    func start() async {
        refresh()
        relay.activate()
        if syncsThroughICloud { cloud.start() }
        reader.prewarm()
        do {
            try await speech.prepare()
            speechReady = true
        } catch {
            speechReady = false
        }
    }

    // MARK: - Today

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { await rebuild() }
    }

    private func rebuild() async {
        let now = Date()
        guard let pick = library.wordOfTheDay(on: now) else {
            card = nil
            publish(nil)
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
        let example = await example(for: pick, entry: entry, on: now)
        guard !Task.isCancelled else { return }
        let card = WordCard(
            pick: pick, entry: entry, example: example, metToday: metToday, strength: strength)
        self.card = card
        publish(TodaySnapshot(card: card, on: now))
    }

    /// One model-written example per word per day, kept so the card reads
    /// the same each time; the user's own example needs no model.
    private func example(for pick: DailyPick, entry: LibraryEntry?, on day: Date) async -> String? {
        if entry?.example != nil { return nil }
        let key = TodaySnapshot.dayKey(for: day) + "|" + pick.term
        if let kept = defaults.dictionary(forKey: "wordOfTheDayExample") as? [String: String],
            let text = kept[key]
        {
            return text
        }
        let meaning: String? = {
            if let own = entry?.meaning { return own }
            if case .bundled(_, let word) = pick.source { return word.definition }
            return nil
        }()
        let written = await writer.write(
            for: pick.term, meaning: meaning, industry: library.profile.industries.first)
        if let written { defaults.set([key: written], forKey: "wordOfTheDayExample") }
        return written
    }

    /// The widgets read this; they never open the Library.
    private func publish(_ snapshot: TodaySnapshot?) {
        if let snapshot {
            try? snapshot.write(to: SharedContainer.snapshotURL)
        } else {
            TodaySnapshot.remove(at: SharedContainer.snapshotURL)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func readCard() {
        guard let card else { return }
        var text = card.term
        if let meaning = card.meanings.first { text += ". " + meaning.text }
        if let example = card.example { text += ". " + example.text }
        reader.read(text)
    }

    // MARK: - Speaking

    /// Asks once; iOS remembers the answer.
    func microphoneAllowed() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    /// Press: the stream carries what has been heard so far.
    func beginListening(vocabulary: [String] = []) async throws -> AsyncStream<TranscriptSnapshot> {
        let stream = try await speech.begin(vocabulary: vocabulary)
        isListening = true
        return stream
    }

    /// Release: the finished transcript.
    func endListening() async throws -> String {
        defer { isListening = false }
        return try await speech.end()
    }

    func cancelListening() async {
        await speech.cancel()
        isListening = false
    }

    // MARK: - Practice

    func practiceQueue() -> [LibraryEntry] {
        PracticeQueue.next(from: library.entries, events: library.events, at: Date())
    }

    func record(_ verdict: DrillVerdict, drill: Drill, for entry: LibraryEntry) {
        library.record(verdict.passed ? .passed : .failed, for: entry.id, drill: drill)
    }

    /// Checks first; the judge only where the words cannot tell
    /// (GDR-0023, decision 5).
    func verdict(for drill: Drill, entry: LibraryEntry, spoken: String) async -> DrillVerdict {
        switch drill {
        case .spellIt:
            let check = SpellCheck.check(entry.term, against: spoken)
            return DrillVerdict(
                passed: check.passed,
                reason: check.passed
                    ? "Spelled it: \(check.heard.uppercased())."
                    : (check.heard.isEmpty
                        ? "No letters heard."
                        : "Heard \(check.heard.uppercased()); it is \(check.expected.uppercased())."))
        case .sayIt:
            if let early = SayItGuardrail.verdict(
                for: SayItGuardrail.failures(in: spoken, for: entry.term), term: entry.term)
            {
                return early
            }
            if let judged = await judge.judgeSayIt(term: entry.term, meaning: entry.meaning, sentence: spoken)
            {
                return judged
            }
            return DrillVerdict(passed: false, reason: "The judge could not answer; try again.")
        case .explainIt:
            switch ExplainItCheck.check(term: entry.term, meaning: entry.meaning ?? "", explanation: spoken) {
            case .passed(let verdict), .failed(let verdict):
                return verdict
            case .unsure:
                if let judged = await judge.judgeExplainIt(
                    term: entry.term, meaning: entry.meaning ?? "", explanation: spoken)
                {
                    return judged
                }
                return DrillVerdict(passed: false, reason: "It means: \(entry.meaning ?? "")")
            }
        }
    }

    // MARK: - To-dos (GDR-0016)

    func addTodo(spoken: String) async throws -> (todo: Todo, list: String) {
        let todo = TodoParser.parse(spoken.trimmingCharacters(in: CharacterSet(charactersIn: ".!")))
        return (todo, try await file(todo))
    }

    /// Into the Timbre list; asks for Reminders the first time.
    func file(_ todo: Todo) async throws -> String {
        if reminders.authorization == .notDetermined {
            _ = await reminders.requestAccess()
        }
        return try reminders.add(todo)
    }

    func openTodos() async throws -> (list: String, todos: [Todo]) {
        if reminders.authorization == .notDetermined {
            _ = await reminders.requestAccess()
        }
        return try await reminders.openTodos()
    }
}

extension CompanionModel {
    /// The toggle (GDR-0010): off by default; stopping keeps what is on the phone.
    var syncsThroughICloud: Bool {
        get { UserDefaults.standard.bool(forKey: "librarySyncsThroughICloud") }
        set {
            UserDefaults.standard.set(newValue, forKey: "librarySyncsThroughICloud")
            if newValue { cloud.start() } else { cloud.stop() }
        }
    }
}
