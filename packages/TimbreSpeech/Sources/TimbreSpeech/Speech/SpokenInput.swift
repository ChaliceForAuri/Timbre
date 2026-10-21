import AVFoundation
import Foundation
import Speech

/// Press, speak, release: one spoken utterance as text, for a drill or a
/// to-do on the phone (GDR-0026). Composes `AudioCapture` and
/// `Transcriber` the way the Mac's controller does, without the overlay,
/// the pasteboard or the hotkey. Live snapshots stream while the press is
/// held; `end()` returns the finished transcript.
public final class SpokenInput {

    public private(set) var isListening = false

    private let audio = AudioCapture()
    private let transcriber = Transcriber()
    private var prepared = false

    public init() {}

    /// Resolves the locale and installs the model's assets. Once, at launch.
    public func prepare() async throws {
        guard !prepared else { return }
        try await transcriber.prepare()
        prepared = true
    }

    /// Opens the microphone and starts a session. The stream carries what
    /// has been heard so far, finalized and volatile, until `end()`.
    public func begin(vocabulary: [String] = []) async throws -> AsyncStream<TranscriptSnapshot> {
        try await prepare()
        guard let format = await transcriber.analyzerFormat else { throw Failure.notReady }
        #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord, mode: .default, options: [.duckOthers, .allowBluetoothHFP])
            try session.setActive(true)
        #endif
        let streams = try audio.start(convertingTo: format)
        isListening = true
        return try await transcriber.startDictation(consuming: streams.input, vocabulary: vocabulary)
    }

    /// Closes the microphone and waits for the model's last word.
    public func end() async throws -> String {
        guard isListening else { return "" }
        audio.stop()
        isListening = false
        return try await transcriber.finishDictation()
    }

    /// Closes the microphone and drops the session without a result.
    public func cancel() async {
        guard isListening else { return }
        audio.stop()
        isListening = false
        await transcriber.abandonDictation()
    }

    public enum Failure: LocalizedError {
        case notReady

        public var errorDescription: String? {
            switch self {
            case .notReady: "The speech model is not ready yet."
            }
        }
    }
}
