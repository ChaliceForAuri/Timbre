import Foundation

/// Where a dictation's time went, in milliseconds. Recorded so the warm-up
/// complaint ("it clips me if I speak too soon") is a number, not a feeling —
/// and later, a Backstage chart.
nonisolated public struct DictationTimings: Codable, Sendable {
    /// Hotkey press → audio engine running. Our code's share of the wait.
    public let microphoneStartMs: Int
    /// Hotkey press → first buffer actually heard. The honest "you can speak
    /// now" moment; on Bluetooth mics the gap to `microphoneStartMs` is the
    /// headset waking its microphone, which no code of ours can shrink.
    public let firstAudioMs: Int
    /// Key release → final transcript out of the analyzer.
    public let transcriptMs: Int
    /// Transcript → polished text ready to paste.
    public let polishMs: Int

    public init(microphoneStartMs: Int, firstAudioMs: Int, transcriptMs: Int, polishMs: Int) {
        self.microphoneStartMs = microphoneStartMs
        self.firstAudioMs = firstAudioMs
        self.transcriptMs = transcriptMs
        self.polishMs = polishMs
    }
}

extension Duration {
    /// Whole milliseconds, for timing records.
    var wholeMilliseconds: Int {
        Int(components.seconds * 1000) + Int(components.attoseconds / 1_000_000_000_000_000)
    }
}

/// One dictation, as it happened: what the speech model heard and what Timbre
/// pasted.
///
/// The raw transcript is the interesting half. Tuning the polisher needs real
/// input — hesitation, restarts, the transcriber's own mistakes — and none of
/// that can be written by hand or synthesised with `say`.
nonisolated public struct DictationRecord: Codable, Sendable {
    public let id: String
    public let date: Date
    public let appContext: String?
    /// Exactly what `Transcriber` produced, before any cleanup.
    public let transcript: String
    /// What was pasted, after polishing and sentence termination.
    public let polished: String

    /// Where the time went. Absent on records from before this was measured.
    public let timings: DictationTimings?

    public init(
        id: String,
        date: Date,
        appContext: String?,
        transcript: String,
        polished: String,
        timings: DictationTimings? = nil
    ) {
        self.id = id
        self.date = date
        self.appContext = appContext
        self.transcript = transcript
        self.polished = polished
        self.timings = timings
    }
}
