/// Merges the speech model's two result kinds into one running transcript.
///
/// The model reports *finalized* text (confirmed, will never change) and
/// *volatile* text (its current best guess for audio it's still hearing).
/// Finalized text accumulates; each volatile result replaces the previous one.
nonisolated struct TranscriptAccumulator {

    private var finalizedText = ""
    private var volatileText = ""

    /// Everything heard so far, finalized plus in-flight.
    var currentText: String {
        (finalizedText + volatileText).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func apply(_ text: String, isFinal: Bool) {
        if isFinal {
            finalizedText += text
            volatileText = ""
        } else {
            volatileText = text
        }
    }
}
