import AVFoundation
import Foundation
import Speech

/// Wraps Apple's on-device streaming speech model (macOS 26+).
///
/// An `actor` because its state is touched from wherever the analyzer's
/// result stream resumes; the compiler serializes access for us.
actor Transcriber {

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var resultsTask: Task<Void, Never>?
    private var accumulator = TranscriptAccumulator()

    /// The audio format the model wants. Nil until `prepare()` has run.
    private(set) var analyzerFormat: AVAudioFormat?

    // MARK: - Setup

    /// True if this locale can run fully on-device right now.
    static func isSupported(locale: Locale = .current) async -> Bool {
        await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil
    }

    /// Downloads the language model if needed and boots the analyzer.
    /// Call once at launch, not on the hotkey press — the first run may pull
    /// down model assets.
    func prepare(locale: Locale = .current) async throws {
        // Resolve to a locale the model actually ships, rather than passing
        // Locale.current blindly (en_GB vs en_US style mismatches fail quietly).
        guard let resolved = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw TranscriberError.localeUnsupported(locale.identifier)
        }

        // `.progressiveTranscription` = stream volatile results as the user
        // speaks, firming them up as the model gains confidence.
        let transcriber = SpeechTranscriber(locale: resolved, preset: .progressiveTranscription)
        self.transcriber = transcriber

        // Model assets are downloaded on demand, per language.
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        analyzer = SpeechAnalyzer(modules: [transcriber])
    }

    // MARK: - Dictation lifecycle

    /// Begins a dictation session consuming model-ready audio, and returns a
    /// stream of transcript snapshots for live display. The snapshot stream
    /// finishes when the session does.
    func startDictation(consuming input: AsyncStream<AnalyzerInput>) async throws -> AsyncStream<String> {
        guard let analyzer, let transcriber else {
            throw TranscriberError.notPrepared
        }

        accumulator = TranscriptAccumulator()

        try await analyzer.start(inputSequence: input)

        let (snapshots, continuation) = AsyncStream<String>.makeStream()
        resultsTask = Task {
            do {
                for try await result in transcriber.results {
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
        // Flushes any audio still in the model's buffer, so the last word or
        // two isn't lost.
        try await analyzer?.finalizeAndFinishThroughEndOfInput()

        // The results sequence terminates once the analyzer finishes; await
        // it so the final result is applied before we read the transcript.
        // Cancelling instead could drop the tail of the utterance.
        await resultsTask?.value
        resultsTask = nil

        let text = accumulator.currentText
        accumulator = TranscriptAccumulator()
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
