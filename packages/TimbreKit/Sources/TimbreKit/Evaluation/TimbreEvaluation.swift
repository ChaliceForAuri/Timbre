import AVFoundation
import Foundation

/// Development-only entry points for the `timbre-eval` harness.
///
/// TimbreKit's app-facing API is `DictationController` alone. This is a second,
/// deliberately narrow seam so the evaluation tool can drive the polisher and
/// the file-input path without either becoming public. It is not part of the
/// app's contract and nothing in `apps/Timbre` may call it — see ADR-0004.
public enum TimbreEvaluation {

    /// Whether the on-device model can run, with a reason when it can't.
    public static var polisherAvailability: (isReady: Bool, reason: String?) {
        TextPolisher.availability
    }

    /// Runs one transcript through the real polisher — same instructions,
    /// same guardrail, same fallback as a live dictation.
    public static func polish(
        _ transcript: String,
        appContext: String? = nil,
        vocabulary: [String] = [],
        corrections: [Correction] = []
    ) async -> String {
        await TextPolisher().polish(
            transcript, appContext: appContext, vocabulary: vocabulary, corrections: corrections
        )
    }

    /// Runs one command over a selection through the real transformer — same
    /// instructions, same guardrail as command mode (GDR-0012).
    public static func transform(
        _ command: VoiceCommand,
        text: String,
        corrections: [Correction] = [],
        acronyms: [Acronym] = [],
        onExplanation: ((String) -> Void)? = nil
    ) async -> CommandResult {
        let (outcome, diagnostic) = await TextTransformer().runDetailed(
            command, on: text, corrections: corrections, acronyms: acronyms, onExplanation: onExplanation
        )
        switch outcome {
        case .replacement(let output): return CommandResult(kind: .replacement, text: output)
        case .explanation(let output, _): return CommandResult(kind: .explanation, text: output)
        case .unchanged: return CommandResult(kind: .unchanged, text: text)
        case .failure(let message):
            return CommandResult(kind: .failure, text: message, diagnostic: diagnostic)
        }
    }

    /// What command mode would make of a transcript; nil means it would do nothing.
    public static func parseCommand(_ transcript: String) -> VoiceCommand? {
        VoiceCommand.parse(transcript)
    }

    /// The taught terms that did not come back verbatim — the transcriber's
    /// recall of the vocabulary it was given (ADR-0008).
    public static func missingVocabulary(_ terms: [String], in transcript: String) -> [String] {
        ContextualVocabulary.missingTerms(from: terms, in: transcript)
    }

    /// Transcribes a recorded audio file through the same conversion and drain
    /// path live microphone audio takes, with the taught vocabulary the app
    /// would pass for it.
    public static func transcribe(audioFileAt url: URL, vocabulary: [String] = []) async throws -> String {
        let transcriber = Transcriber()
        try await transcriber.prepare()

        guard let format = await transcriber.analyzerFormat else {
            throw EvaluationError.analyzerFormatUnavailable
        }

        let input = try AudioFileInput.stream(contentsOf: url, to: format)
        // The snapshot stream is for live display; the harness only wants the
        // final transcript. AsyncStream buffers unboundedly, so dropping it
        // here can't stall the analyzer.
        _ = try await transcriber.startDictation(consuming: input, vocabulary: vocabulary)
        return try await transcriber.finishDictation()
    }

    /// Transcribes several files through **one** `Transcriber`, the way the
    /// app reuses it across dictations.
    ///
    /// This is the regression harness for ADR-0006: a single-use analyzer that
    /// is not rebuilt per session transcribes the first file and returns empty
    /// for every one after it, silently. One file passing proves nothing.
    public static func transcribeAll(audioFilesAt urls: [URL]) async throws -> [(
        name: String, transcript: String
    )] {
        try await transcribeAll(urls.map { (url: $0, vocabulary: []) })
    }

    /// As above, with a taught vocabulary per file — the corpus case's terms,
    /// in the harness — so the contextual-strings bias can be measured file by
    /// file rather than assumed.
    public static func transcribeAll(
        _ jobs: [(url: URL, vocabulary: [String])]
    ) async throws -> [(name: String, transcript: String)] {
        let transcriber = Transcriber()
        try await transcriber.prepare()

        guard let format = await transcriber.analyzerFormat else {
            throw EvaluationError.analyzerFormatUnavailable
        }

        var results: [(name: String, transcript: String)] = []
        for job in jobs {
            let input = try AudioFileInput.stream(contentsOf: job.url, to: format)
            _ = try await transcriber.startDictation(consuming: input, vocabulary: job.vocabulary)
            results.append((job.url.lastPathComponent, try await transcriber.finishDictation()))
        }
        return results
    }

    /// Transcribes a file at microphone pace, reporting every intermediate
    /// snapshot. This is how to tell whether the model streams partial results
    /// or only reports once at the end — the difference between a live overlay
    /// and one that stays blank until the user lets go.
    public static func streamTranscribe(
        audioFileAt url: URL,
        vocabulary: [String] = [],
        onSnapshot: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let transcriber = Transcriber()
        try await transcriber.prepare()

        guard let format = await transcriber.analyzerFormat else {
            throw EvaluationError.analyzerFormatUnavailable
        }

        let input = try AudioFileInput.stream(contentsOf: url, to: format, pacing: .realTime)
        let snapshots = try await transcriber.startDictation(consuming: input, vocabulary: vocabulary)

        let observer = Task {
            for await snapshot in snapshots { onSnapshot(snapshot) }
        }
        defer { observer.cancel() }

        return try await transcriber.finishDictation()
    }

    /// One spoken command, fed at microphone pace: when its word first
    /// appeared in a live result, and how long dropping the session took.
    public struct LiveCommandResult: Sendable {
        public let name: String
        public let command: VoiceCommand?
        /// From the first audio fed to the live result containing the word.
        public let heardAfter: Duration?
        /// The live result that contained it, or the last one seen.
        public let transcript: String
        public let abandonTook: Duration
    }

    /// Command mode's hot path, measured (GDR-0014): every file through one
    /// `Transcriber`, each abandoned the moment a command word appears, then
    /// `check` transcribed in full on the same transcriber — because a
    /// session ended a new way is exactly how ADR-0006's silent failure
    /// comes back, and one file passing proves nothing.
    public static func liveCommands(
        audioFilesAt urls: [URL],
        thenTranscribe check: URL,
        giveUpAfter limit: Duration = .seconds(6)
    ) async throws -> (results: [LiveCommandResult], check: String) {
        let transcriber = Transcriber()
        try await transcriber.prepare()
        guard let format = await transcriber.analyzerFormat else {
            throw EvaluationError.analyzerFormatUnavailable
        }

        let clock = ContinuousClock()
        var results: [LiveCommandResult] = []
        for url in urls {
            let started = clock.now
            let input = try AudioFileInput.stream(contentsOf: url, to: format, pacing: .realTime)
            let snapshots = try await transcriber.startDictation(consuming: input)

            let watch = Task { () -> (VoiceCommand?, Duration?, String) in
                var last = ""
                for await snapshot in snapshots {
                    last = snapshot
                    if let command = VoiceCommand.recognizedWhileSpeaking(in: snapshot) {
                        return (command, clock.now - started, snapshot)
                    }
                }
                return (nil, nil, last)
            }
            let timeout = Task {
                try? await Task.sleep(for: limit)
                watch.cancel()
            }
            let (command, heardAfter, transcript) = await watch.value
            timeout.cancel()

            let abandonStarted = clock.now
            await transcriber.abandonDictation()
            results.append(
                LiveCommandResult(
                    name: url.lastPathComponent,
                    command: command,
                    heardAfter: heardAfter,
                    transcript: transcript,
                    abandonTook: clock.now - abandonStarted
                )
            )
        }

        let input = try AudioFileInput.stream(contentsOf: check, to: format)
        _ = try await transcriber.startDictation(consuming: input)
        return (results, try await transcriber.finishDictation())
    }

    /// The update pipeline end to end, short of relaunching (ADR-0010):
    /// fetch the feed, decide as a copy of `currentVersion` would, download,
    /// check the hash, unpack and verify the signature. With `installOver`,
    /// also replace that app bundle — a stand-in, never the running app.
    public static func verifyUpdate(
        feed: URL,
        currentVersion: String,
        installOver standIn: URL? = nil
    ) async throws -> (release: AppRelease, verified: URL, installed: URL?) {
        let session = URLSession(configuration: .ephemeral)
        let (data, _) = try await session.data(from: feed)
        let release = try JSONDecoder().decode(Appcast.self, from: data).latest
        switch UpdateDecision.decide(
            release, currentVersion: currentVersion, currentBuild: 0,
            system: ProcessInfo.processInfo.operatingSystemVersion, feed: feed
        ) {
        case .available: break
        case .upToDate: throw UpdateFailure.feed("\(currentVersion) is already current")
        case .needsNewerMacOS: throw UpdateFailure.feed("needs macOS \(release.minimumSystemVersion)")
        case .unusable(let why): throw UpdateFailure.feed(why)
        }
        let verified = try await UpdateInstaller.prepare(release, using: session)
        let installed = try standIn.map { try UpdateInstaller.replace($0, with: verified) }
        return (release, verified, installed)
    }

    /// Whether an app bundle would pass the update signature check.
    public static func updateSignatureAccepts(_ app: URL) -> Bool {
        UpdateVerifier.isRelease(app)
    }

    public enum EvaluationError: LocalizedError {
        case analyzerFormatUnavailable

        public var errorDescription: String? {
            switch self {
            case .analyzerFormatUnavailable:
                return "The speech analyzer did not report a usable audio format."
            }
        }
    }
}
