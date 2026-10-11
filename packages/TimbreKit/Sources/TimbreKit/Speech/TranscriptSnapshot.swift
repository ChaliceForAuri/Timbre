/// One moment of a live transcript: the words the speech model has confirmed
/// and the words it is still hearing.
///
/// Finalized text is settled — the model will never revise it — so it is
/// safe to act on while the user is still talking: typing it into the app,
/// or matching a command word. Volatile text is the current best guess for
/// audio still in flight and is replaced wholesale by the next result.
public nonisolated struct TranscriptSnapshot: Equatable, Sendable {
    /// Everything confirmed so far, in order, exactly as the model spelled it.
    public let finalized: String
    /// The model's guess for what it is hearing right now; may change.
    public let volatile: String

    public init(finalized: String, volatile: String) {
        self.finalized = finalized
        self.volatile = volatile
    }

    /// Everything heard so far, confirmed and in flight, for display.
    public var text: String {
        (finalized + volatile).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
