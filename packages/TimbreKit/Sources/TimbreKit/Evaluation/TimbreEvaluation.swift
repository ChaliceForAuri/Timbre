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
        acronyms: [Acronym] = []
    ) async -> CommandResult {
        let (outcome, diagnostic) = await TextTransformer().runDetailed(
            command, on: text, corrections: corrections, acronyms: acronyms
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
