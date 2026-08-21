import AVFoundation
import Foundation
import Speech

/// Wraps Apple's on-device streaming speech model (macOS 26+).
///
/// An `actor` because its state is touched from wherever the analyzer's
/// result stream resumes; the compiler serializes access for us.
///
/// **A `SpeechAnalyzer` is single-use.** `finalizeAndFinishThroughEndOfInput()`
/// ends it permanently — that is what the `AndFinish` in the name means, and
/// the API offers a plain `finalize(through:)` for the case where you want to
/// keep going. The module's `results` sequence terminates along with it. So an
/// analyzer reused for a second dictation accepts the input, produces nothing,
/// and reports no error: the user holds the key, sees the overlay, speaks, and
/// gets silence. Every dictation therefore builds a fresh analyzer *and* a
/// fresh transcriber module. See ADR-0006.
actor Transcriber {

    /// One dictation's worth of speech machinery. Both halves are single-use.
    private struct Session {
        let analyzer: SpeechAnalyzer
        let transcriber: SpeechTranscriber
    }

    private var locale: Locale?
    private var ready: Session?
    private var active: Session?
    private var resultsTask: Task<Void, Never>?
    private var accumulator = TranscriptAccumulator()

    /// The audio format the model wants. Nil until `prepare()` has run.
    private(set) var analyzerFormat: AVAudioFormat?

    // MARK: - Setup

    /// True if this locale can run fully on-device right now.
    static func isSupported(locale: Locale = .current) async -> Bool {
        await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil
    }

    /// Resolves the locale, installs model assets, and builds the first
    /// session. Call once at launch: asset installation may download, which is
    /// not something to do on a hotkey press.
    func prepare(locale requested: Locale = .current) async throws {
        // Resolve to a locale the model actually ships, rather than passing
        // Locale.current blindly (en_GB vs en_US style mismatches fail quietly).
        guard let resolved = await SpeechTranscriber.supportedLocale(equivalentTo: requested) else {
            throw TranscriberError.localeUnsupported(requested.identifier)
        }
        locale = resolved

        let session = Self.makeSession(locale: resolved)

        // Model assets are downloaded on demand, per language.
        if let request = try await AssetInventory.assetInstallationRequest(
            supporting: [session.transcriber]
        ) {
            try await request.downloadAndInstall()
        }

        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [session.transcriber]
        )

        // Allocate the analyzer's resources now, at launch, rather than
        // inside the first key press. Apple ships this API for exactly the
        // warm-up complaint in issue #4. Failure is fine — analysis then
        // prepares lazily, exactly as before.
        try? await session.analyzer.prepareToAnalyze(in: analyzerFormat)
        ready = session
    }

    /// `.progressiveTranscription` streams volatile results as the user
    /// speaks, firming them up as the model gains confidence.
    private static func makeSession(locale: Locale) -> Session {
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        return Session(analyzer: SpeechAnalyzer(modules: [transcriber]), transcriber: transcriber)
    }

    // MARK: - Dictation lifecycle

    /// Begins a dictation consuming model-ready audio, and returns a stream of
    /// transcript snapshots for live display. The snapshot stream finishes
    /// when the session does.
    func startDictation(consuming input: AsyncStream<AnalyzerInput>) async throws -> AsyncStream<
        String
    > {
        guard let locale else { throw TranscriberError.notPrepared }

        // Normally already built — by prepare(), or by the previous
        // finishDictation() — so the key press pays nothing for it.
        let session = ready ?? Self.makeSession(locale: locale)
        ready = nil
        active = session
        accumulator = TranscriptAccumulator()

        try await session.analyzer.start(inputSequence: input)

        let (snapshots, continuation) = AsyncStream<String>.makeStream()
        resultsTask = Task {
            do {
                for try await result in session.transcriber.results {
                    accumulator.apply(String(result.text.characters), isFinal: result.isFinal)
                    continuation.yield(accumulator.currentText)
                }
            } catch {
                // Stream ended or errored; finishDictation() reports whatever
                // text we already have rather than losing the utterance.
            }
            continuation.finish()
        }

        return snapshots
    }

    /// Ends the session and returns the complete transcript. The audio input
    /// stream must already be finished (i.e. `AudioCapture.stop()` first).
    func finishDictation() async throws -> String {
        guard let session = active else { return "" }

        // Flushes audio still in the model's buffer, so the last word or two
        // isn't lost — and finishes this analyzer for good.
        //
        // The watchdog exists because finalize never returns when the
        // analyzer received no audio at all (observed with no microphone
        // connected: the engine starts cleanly and delivers nothing, and the
        // release-key path then suspends forever). cancelAndFinishNow() is
        // Apple's escape hatch for exactly this; the accumulated transcript —
        // empty, in that case — still comes back below, so no utterance that
        // did produce audio is ever lost to the timeout.
        let watchdog = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await session.analyzer.cancelAndFinishNow()
        }
        defer { watchdog.cancel() }
        try? await session.analyzer.finalizeAndFinishThroughEndOfInput()

        // The results sequence terminates once the analyzer finishes; await it
        // so the final result is applied before we read the transcript.
        // Cancelling instead could drop the tail of the utterance.
        await resultsTask?.value
        resultsTask = nil
        active = nil

        let text = accumulator.currentText
        accumulator = TranscriptAccumulator()

        // Build the next one now rather than on the next key press, and warm
        // it up off the hot path — this runs after the transcript is already
        // on its way back to the user.
        if let locale {
            let next = Self.makeSession(locale: locale)
            ready = next
            let format = analyzerFormat
            Task { try? await next.analyzer.prepareToAnalyze(in: format) }
        }

        return text
    }

    enum TranscriberError: LocalizedError {
        case notPrepared
        case localeUnsupported(String)

        var errorDescription: String? {
            switch self {
            case .notPrepared:
                return "Speech model isn't ready yet. Wait for setup to finish."
            case .localeUnsupported(let id):
                return "On-device speech isn't available for \(id)."
            }
        }
    }
}
