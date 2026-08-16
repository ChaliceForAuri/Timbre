import AVFoundation
import Foundation
import Speech

/// Wraps Apple's on-device streaming speech model (macOS 26+).
///
/// This replaces Wispr Flow's entire cloud transcription tier. No API key,
/// no network, no per-word billing. The model runs on the Neural Engine.
///
/// Swift note for Flutter/RN devs: this is an `actor`. Think of it as a class
/// that guarantees only one task touches its state at a time — the compiler
/// enforces it. That's why callers must `await` its methods.
@available(macOS 26.0, *)
actor Transcriber {

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private let bufferConverter = BufferConverter()

    /// The audio format the model wants. Nil until `prepare()` has run.
    private(set) var analyzerFormat: AVAudioFormat?

    /// Text confirmed by the model. Won't change again.
    private var finalizedText = ""
    /// The model's current best guess for audio it's still hearing.
    private var volatileText = ""

    /// Everything we have so far, finalized plus in-flight.
    var currentText: String {
        (finalizedText + volatileText).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Setup

    /// Downloads the language model if needed and boots the analyzer.
    /// Call this once before the first dictation — the first run may pull
    /// down a model, so do it at launch, not on the hotkey press.
    func prepare(locale: Locale = Locale.current) async throws {
        // Resolve to a locale the model actually ships, rather than passing
        // Locale.current blindly (en_GB vs en_US style mismatches fail quietly).
        guard let resolved = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw TranscriberError.localeUnsupported(locale.identifier)
        }

        // Ask for a transcriber that streams partial results as you speak.
        let transcriber = SpeechTranscriber(
            locale: resolved,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        self.transcriber = transcriber

        // Model assets are downloaded on demand, per language.
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        analyzer = SpeechAnalyzer(modules: [transcriber])
    }

    /// True if this locale can run fully on-device right now.
    static func isSupported(locale: Locale = Locale.current) async -> Bool {
        await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil
    }

    // MARK: - Dictation lifecycle

    /// Begins a dictation session. `onUpdate` fires as text arrives, so you
    /// can show live text in the overlay while the user is still talking.
    func startDictation(onUpdate: @escaping @Sendable (String) -> Void) async throws {
        guard let analyzer, let transcriber else {
            throw TranscriberError.notPrepared
        }

        finalizedText = ""
        volatileText = ""

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation

        try await analyzer.start(inputSequence: stream)

        // Consume results in the background. Volatile results get replaced as
        // the model firms up its guess; finalized results are appended.
        resultsTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    await self.apply(text: text, isFinal: result.isFinal)
                    let snapshot = await self.currentText
                    onUpdate(snapshot)
                }
            } catch {
                // Stream ended or errored; the finish() path reports the text
                // we already have rather than losing the whole utterance.
            }
        }
    }

    private func apply(text: String, isFinal: Bool) {
        if isFinal {
            finalizedText += text
            volatileText = ""
        } else {
            volatileText = text
        }
    }

    /// Feed a mic buffer in. Handles format conversion for you.
    func feed(_ buffer: AVAudioPCMBuffer) {
        guard let analyzerFormat, let inputContinuation else { return }
        do {
            let converted = try bufferConverter.convert(buffer, to: analyzerFormat)
            inputContinuation.yield(AnalyzerInput(buffer: converted))
        } catch {
            // Dropping a single buffer is better than tearing down the session.
        }
    }

    /// Ends the session and returns the complete transcript.
    func finishDictation() async throws -> String {
        inputContinuation?.finish()
        inputContinuation = nil

        // `finalizeAndFinishThroughEndOfInput` flushes any audio still in the
        // model's buffer, so you don't lose the last word or two.
        try await analyzer?.finalizeAndFinishThroughEndOfInput()

        resultsTask?.cancel()
        resultsTask = nil

        let text = currentText
        finalizedText = ""
        volatileText = ""
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
