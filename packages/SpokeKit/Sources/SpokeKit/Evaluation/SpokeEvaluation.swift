import AVFoundation
import Foundation

/// Development-only entry points for the `spoke-eval` harness.
///
/// SpokeKit's app-facing API is `DictationController` alone. This is a second,
/// deliberately narrow seam so the evaluation tool can drive the polisher and
/// the file-input path without either becoming public. It is not part of the
/// app's contract and nothing in `apps/Spoke` may call it — see ADR-0004.
public enum SpokeEvaluation {

    /// Whether the on-device model can run, with a reason when it can't.
    public static var polisherAvailability: (isReady: Bool, reason: String?) {
        TextPolisher.availability
    }

    /// Runs one transcript through the real polisher — same instructions,
    /// same guardrail, same fallback as a live dictation.
    public static func polish(
        _ transcript: String,
        appContext: String? = nil,
        vocabulary: [String] = []
    ) async -> String {
        await TextPolisher().polish(transcript, appContext: appContext, vocabulary: vocabulary)
    }

    /// Transcribes a recorded audio file through the same conversion and drain
    /// path live microphone audio takes.
    public static func transcribe(audioFileAt url: URL) async throws -> String {
        let transcriber = Transcriber()
        try await transcriber.prepare()

        guard let format = await transcriber.analyzerFormat else {
            throw EvaluationError.analyzerFormatUnavailable
        }

        let input = try AudioFileInput.stream(contentsOf: url, to: format)
        // The snapshot stream is for live display; the harness only wants the
        // final transcript. AsyncStream buffers unboundedly, so dropping it
        // here can't stall the analyzer.
        _ = try await transcriber.startDictation(consuming: input)
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
