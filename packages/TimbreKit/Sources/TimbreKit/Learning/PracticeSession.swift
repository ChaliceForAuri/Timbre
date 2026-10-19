import Foundation
import Observation
import TimbreCore
import TimbreModel
import TimbreSpeech

/// One sitting of practice on the Mac (GDR-0023, decision 5): the queue,
/// the drill each entry gets today, the hold-to-talk round, the check or
/// the judge, and the event that records it. The Mac has the microphone
/// pipeline and the model, so all three drills run here.
@Observable
public final class PracticeSession {

    public enum Phase: Equatable, Sendable {
        case idle
        case listening
        case checking
        case verdict(DrillVerdict, heard: String)
        case done
    }

    public private(set) var queue: [LibraryEntry] = []
    public private(set) var index = 0
    public private(set) var phase: Phase = .idle
    public private(set) var live = ""
    public private(set) var problem: String?

    public var current: LibraryEntry? { queue.indices.contains(index) ? queue[index] : nil }
    public var drill: Drill? {
        current.map { DrillPlanner.drill(for: $0, on: Date(), withModel: OnDeviceModel.availability.isReady) }
    }
    public var remaining: Int { max(0, queue.count - index) }

    private let library: Library
    private let speech: SpokenInput
    private let reader: SpeechReader
    private let judge: any DrillJudge
    private var streamTask: Task<Void, Never>?

    init(
        library: Library, speech: SpokenInput = SpokenInput(), reader: SpeechReader,
        judge: any DrillJudge = ModelDrillJudge()
    ) {
        self.library = library
        self.speech = speech
        self.reader = reader
        self.judge = judge
    }

    /// A fresh queue: due words weakest first, then the freshest.
    public func begin(limit: Int = 10) {
        queue = PracticeQueue.next(from: library.entries, events: library.events, at: Date(), limit: limit)
        index = 0
        phase = queue.isEmpty ? .done : .idle
        live = ""
        problem = nil
    }

    /// Hear the word, for a round with no meaning to show.
    public func hearTheWord() {
        guard let entry = current else { return }
        reader.read(entry.term)
    }

    /// The press: the microphone opens, live text streams.
    public func press() {
        guard current != nil, phase == .idle else { return }
        phase = .listening
        live = ""
        problem = nil
        streamTask?.cancel()
        streamTask = Task {
            do {
                let stream = try await speech.begin(vocabulary: current.map { [$0.term] } ?? [])
                for await snapshot in stream { live = snapshot.text }
            } catch {
                problem = error.localizedDescription
                phase = .idle
            }
        }
    }

    /// The release: the transcript is checked, or judged, and recorded.
    public func release() {
        guard phase == .listening, let entry = current, let drill else { return }
        phase = .checking
        Task {
            do {
                let spoken = try await speech.end()
                let verdict = await verdict(for: drill, entry: entry, spoken: spoken)
                library.record(verdict.passed ? .passed : .failed, for: entry.id, drill: drill)
                phase = .verdict(verdict, heard: spoken)
            } catch {
                problem = error.localizedDescription
                phase = .idle
            }
        }
    }

    public func next() {
        index += 1
        live = ""
        phase = current == nil ? .done : .idle
    }

    public func cancel() {
        streamTask?.cancel()
        Task { await speech.cancel() }
        phase = current == nil ? .done : .idle
    }

    /// Checks come first; the judge only where the words cannot tell.
    private func verdict(for drill: Drill, entry: LibraryEntry, spoken: String) async -> DrillVerdict {
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
}
