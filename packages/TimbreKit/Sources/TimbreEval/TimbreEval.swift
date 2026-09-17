import Foundation
import TimbreKit

/// Runs dictation samples through the real polisher and reports which
/// properties held.
///
/// This exists because polisher tuning is otherwise unmeasurable: with live
/// speech the input changes every take, so you can never tell whether a prompt
/// edit helped or you just spoke more clearly. A fixed corpus makes the change
/// the only variable.
@main
struct TimbreEval {

    static func main() async {
        do {
            try await run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            printErr("timbre-eval: \(error.localizedDescription)")
            printErr("  detail: \(error)")
            exit(1)
        }
    }

    // MARK: - Dispatch

    private static func run(arguments: [String]) async throws {
        if arguments.contains("--help") || arguments.isEmpty {
            print(usage)
            return
        }

        if let path = value(for: "--import", in: arguments) {
            try runImport(path: path, output: value(for: "--out", in: arguments))
            return
        }

        if let path = value(for: "--commands", in: arguments) {
            try await runCommands(
                path: path,
                repeats: value(for: "--repeat", in: arguments).flatMap(Int.init) ?? 1
            )
            return
        }

        let vocabulary = value(for: "--vocabulary", in: arguments).map(parseVocabulary)

        if let path = value(for: "--stream", in: arguments) {
            try await runStream(path: path, vocabulary: vocabulary ?? [])
            return
        }

        if let directory = value(for: "--audio-dir", in: arguments) {
            try await runAudioDirectory(
                path: directory,
                corpusPath: value(for: "--corpus", in: arguments),
                vocabularyOverride: vocabulary
            )
            return
        }

        if let path = value(for: "--audio", in: arguments) {
            try await runAudio(path: path, vocabulary: vocabulary ?? [])
            return
        }

        guard let corpusPath = arguments.first(where: { !$0.hasPrefix("--") }) else {
            print(usage)
            return
        }
        try await runCorpus(
            path: corpusPath,
            jsonOutput: value(for: "--json", in: arguments),
            repeats: value(for: "--repeat", in: arguments).flatMap(Int.init) ?? 1
        )
    }

    // MARK: - Corpus mode

    private static func runCorpus(path: String, jsonOutput: String?, repeats: Int) async throws {
        let corpus = try JSONDecoder().decode(
            DictationCorpus.self,
            from: try Data(contentsOf: URL(filePath: path))
        )

        let availability = TimbreEvaluation.polisherAvailability
        print("timbre-eval — \(corpus.cases.count) cases")
        print("model: \(availability.reason ?? "available")")
        if !availability.isReady {
            // Without the model, polish() returns its input unchanged. Every
            // case would "run" and report meaningless results, so stop.
            printErr("\nThe on-device model is unavailable, so nothing would be polished.")
            exit(2)
        }
        print("")

        var allRuns: [CaseOutcome] = []
        var solidCases = 0

        for testCase in corpus.cases {
            var runs: [CaseOutcome] = []
            for _ in 0..<repeats {
                let output = await TimbreEvaluation.polish(
                    testCase.transcript,
                    appContext: testCase.appContext,
                    vocabulary: testCase.vocabulary,
                    corrections: testCase.corrections
                )
                runs.append(
                    CaseOutcome(
                        id: testCase.id,
                        input: testCase.transcript,
                        output: output,
                        failures: PolishChecks.failures(for: testCase, output: output)
                    )
                )
            }
            allRuns.append(contentsOf: runs)
            if runs.allSatisfy(\.passed) { solidCases += 1 }
            report(testCase: testCase, runs: runs)
        }

        let passedRuns = allRuns.count(where: \.passed)
        print("cases passing every run: \(solidCases)/\(corpus.cases.count)")
        print("individual runs passing: \(passedRuns)/\(allRuns.count)")
        let passed = solidCases
        let outcomes = corpus.cases

        if let jsonOutput {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(allRuns).write(to: URL(filePath: jsonOutput))
            print("wrote \(jsonOutput)")
        }

        if passed != outcomes.count { exit(1) }
    }

    /// Prints one case, folding its repeats together. Distinct outputs are
    /// listed separately: seeing the model disagree with itself across runs is
    /// the signal that a prompt is underspecified rather than wrong.
    private static func report(testCase: DictationCase, runs: [CaseOutcome]) {
        let passes = runs.count(where: \.passed)
        let mark = passes == runs.count ? "✓" : "✗"
        print("\(mark) \(testCase.id)  \(passes)/\(runs.count)")
        if let note = testCase.note { print("     \(note)") }
        print("  in   \(testCase.transcript)")

        for output in Set(runs.map(\.output)).sorted() {
            print("  out  \(singleLine(output))")
        }

        var tally: [String: Int] = [:]
        for run in runs {
            for failure in run.failures { tally[failure, default: 0] += 1 }
        }
        for (failure, count) in tally.sorted(by: { $0.key < $1.key }) {
            let suffix = runs.count > 1 ? "  (\(count) of \(runs.count))" : ""
            print("  ·    \(failure)\(suffix)")
        }
        print("")
    }

    /// Keeps a multi-line polish from wrecking the report's alignment.
    private static func singleLine(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .joined(separator: " ⏎ ")
    }

    // MARK: - Command mode

    /// Runs every command case through the real transformer. Same discipline
    /// as the polisher corpus: properties, repeats, non-zero exit on a miss.
    private static func runCommands(path: String, repeats: Int) async throws {
        let corpus = try JSONDecoder().decode(
            CommandCorpus.self,
            from: try Data(contentsOf: URL(filePath: path))
        )

        let availability = TimbreEvaluation.polisherAvailability
        print("timbre-eval — \(corpus.cases.count) command cases")
        print("model: \(availability.reason ?? "available")\n")
        if !availability.isReady {
            printErr("The on-device model is unavailable, so no command would run.")
            exit(2)
        }

        var solid = 0
        var passedRuns = 0
        for testCase in corpus.cases {
            var outputs: [String] = []
            var tally: [String: Int] = [:]
            var passes = 0
            for _ in 0..<repeats {
                let result = await TimbreEvaluation.transform(
                    testCase.command,
                    text: testCase.text,
                    corrections: testCase.corrections,
                    acronyms: testCase.acronyms
                )
                let failures = CommandChecks.failures(for: testCase, result: result)
                if failures.isEmpty { passes += 1 }
                for failure in failures { tally[failure, default: 0] += 1 }
                if !outputs.contains(result.text) { outputs.append(result.text) }
                if let why = result.diagnostic, !outputs.contains("  ↳ \(why)") {
                    outputs.append("  ↳ \(why)")
                }
            }
            passedRuns += passes
            if passes == repeats { solid += 1 }

            print(
                "\(passes == repeats ? "✓" : "✗") \(testCase.id)  [\(testCase.command.rawValue)]  \(passes)/\(repeats)"
            )
            if let note = testCase.note { print("     \(note)") }
            print("  in   \(singleLine(testCase.text))")
            for output in outputs { print("  out  \(singleLine(output))") }
            for (failure, count) in tally.sorted(by: { $0.key < $1.key }) {
                print("  ·    \(failure)\(repeats > 1 ? "  (\(count) of \(repeats))" : "")")
            }
            print("")
        }

        print("cases passing every run: \(solid)/\(corpus.cases.count)")
        print("individual runs passing: \(passedRuns)/\(corpus.cases.count * repeats)")
        if solid != corpus.cases.count { exit(1) }
    }

    // MARK: - Audio mode

    private static func runAudio(path: String, vocabulary: [String]) async throws {
        let url = URL(filePath: path)
        print("transcribing \(url.lastPathComponent)…")

        let transcript = try await TimbreEvaluation.transcribe(audioFileAt: url, vocabulary: vocabulary)
        print("  transcript  \(transcript)")
        for term in TimbreEvaluation.missingVocabulary(vocabulary, in: transcript) {
            print("  ·    missed \"\(term)\"")
        }

        guard TimbreEvaluation.polisherAvailability.isReady else {
            printErr("  (model unavailable — transcript not polished)")
            return
        }
        print("  polished    \(await TimbreEvaluation.polish(transcript))")
    }

    /// Transcribes every fixture in a directory through one Transcriber —
    /// the reuse the app depends on and that a single file cannot exercise.
    ///
    /// With `--corpus`, each file is paired with the case of the same id and
    /// transcribed with that case's taught vocabulary; the report then says
    /// which taught terms came back verbatim. Run it with and without the
    /// corpus to measure what the bias buys (ADR-0008).
    private static func runAudioDirectory(
        path: String,
        corpusPath: String?,
        vocabularyOverride: [String]?
    ) async throws {
        let directory = URL(filePath: path)
        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { ["aiff", "aif", "wav", "caf", "m4a"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !files.isEmpty else {
            printErr("no audio files in \(path)")
            exit(1)
        }

        var casesByID: [String: DictationCase] = [:]
        if let corpusPath {
            let corpus = try JSONDecoder().decode(
                DictationCorpus.self,
                from: try Data(contentsOf: URL(filePath: corpusPath))
            )
            casesByID = Dictionary(corpus.cases.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }
        let jobs = files.map { url in
            let caseID = url.deletingPathExtension().lastPathComponent
            return (url: url, vocabulary: vocabularyOverride ?? casesByID[caseID]?.vocabulary ?? [])
        }
        let taught = jobs.reduce(0) { $0 + $1.vocabulary.count }
        let suffix = taught > 0 ? ", \(taught) taught terms" : ""
        print("transcribing \(files.count) files through one Transcriber\(suffix)\n")

        var empty = 0
        var recalled = 0
        for (job, result) in zip(jobs, try await TimbreEvaluation.transcribeAll(jobs)) {
            let transcript = result.transcript
            let ok = !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if !ok { empty += 1 }
            print("\(ok ? "✓" : "✗") \(result.name)")
            print("   \(transcript.isEmpty ? "(empty)" : transcript)")

            let missing = TimbreEvaluation.missingVocabulary(job.vocabulary, in: transcript)
            recalled += job.vocabulary.count - missing.count
            for term in missing { print("  ·    missed \"\(term)\"") }
            print("")
        }

        print("\(files.count - empty)/\(files.count) produced a transcript")
        if taught > 0 { print("taught terms recalled verbatim: \(recalled)/\(taught)") }
        if empty > 0 { exit(1) }
    }

    /// Feeds one file at microphone pace and prints each snapshot as it lands,
    /// so the arrival *timing* of partial results is visible.
    private static func runStream(path: String, vocabulary: [String]) async throws {
        let url = URL(filePath: path)
        print("streaming \(url.lastPathComponent) at microphone pace\n")

        let start = ContinuousClock.now
        let counter = SnapshotCounter()

        let final = try await TimbreEvaluation.streamTranscribe(
            audioFileAt: url, vocabulary: vocabulary
        ) { snapshot in
            let elapsed = ContinuousClock.now - start
            let milliseconds =
                elapsed.components.seconds * 1000
                + elapsed.components.attoseconds / 1_000_000_000_000_000
            counter.increment()
            print(String(format: "  %6d ms  %@", milliseconds, snapshot))
        }

        print("\n\(counter.count) snapshots before finish")
        print("final: \(final)")
        if counter.count <= 1 {
            print("\nOnly one snapshot — the model is not streaming partial results here.")
        }
    }

    /// Converts a captured dictation log into a corpus skeleton.
    private static func runImport(path: String, output: String?) throws {
        let contents = try String(contentsOf: URL(filePath: path), encoding: .utf8)
        let records = CorpusImport.records(fromJSONLines: contents)
        let corpus = CorpusImport.corpus(from: records)

        guard !corpus.cases.isEmpty else {
            printErr("no usable dictations in \(path)")
            exit(1)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(corpus)

        guard let output else {
            print(String(decoding: data, as: UTF8.self))
            return
        }
        try data.write(to: URL(filePath: output))
        print("\(corpus.cases.count) cases → \(output)")
        print("Now add `forbidden` and `required` to each: only you know which")
        print("words had to survive and which filler had to go.")
    }

    // MARK: - Plumbing

    private static let usage = """
        timbre-eval — measure Timbre's cleanup against a fixed corpus

        USAGE
          timbre-eval <corpus.json> [--repeat <n>] [--json <out.json>]
          timbre-eval --commands <commands.json> [--repeat <n>]
                                             command mode: fix, explain, shorten
          timbre-eval --audio <file.aiff> [--vocabulary a,b,c]
          timbre-eval --audio-dir <dir> [--corpus corpus.json] [--vocabulary a,b,c]
                                             one Transcriber, every file; with a
                                             corpus, each file is biased with its
                                             case's vocabulary and recall is reported
          timbre-eval --stream <file.aiff>   microphone pace, timed snapshots
          timbre-eval --import <log.jsonl> [--out corpus.json]

        Exits non-zero when a case fails, so it can gate CI once the model is
        available on the runner.

        The model is stochastic, so a single run is not a measurement. Use
        --repeat 3 or more before believing a prompt change helped: a case that
        passes 2 of 3 has an underspecified instruction, not a fixed one.

        Tuning loop: run it, edit the instructions in TextPolisher, run it
        again. Use --json on both runs and diff them to see what moved.
        """

    /// `--vocabulary "TimbreKit, Supabase"` → the taught terms, trimmed.
    private static func parseVocabulary(_ list: String) -> [String] {
        list.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func value(for flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func printErr(_ message: String) {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
    }
}

/// Counts snapshots arriving from the transcriber's callback, which is
/// `@Sendable` and fires off the main actor.
///
/// `@unchecked Sendable` is justified by the lock: `value` is only ever read
/// or written inside `lock.withLock`, so there is no unsynchronised access to
/// mutable state.
private nonisolated final class SnapshotCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.withLock { value }
    }

    func increment() {
        lock.withLock { value += 1 }
    }
}
