import Foundation

/// One dictation, as it happened: what the speech model heard and what Spoke
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

    public init(
        id: String,
        date: Date,
        appContext: String?,
        transcript: String,
        polished: String
    ) {
        self.id = id
        self.date = date
        self.appContext = appContext
        self.transcript = transcript
        self.polished = polished
    }
}
