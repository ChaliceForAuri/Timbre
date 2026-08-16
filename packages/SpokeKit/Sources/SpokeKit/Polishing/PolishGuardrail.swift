/// Decides whether the language model's cleanup can be trusted over the raw
/// transcript.
///
/// The classic small-model failure modes are "helpfully" summarizing three
/// sentences into one, or refusing and explaining itself. Both show up as a
/// large length change, so a wildly-off ratio means we paste the raw
/// transcript instead. The user must never lose an utterance to cleverness.
nonisolated enum PolishGuardrail {

    private static let minimumLengthRatio = 0.4
    private static let maximumLengthRatio = 2.5

    static func accepts(cleaned: String, raw: String) -> Bool {
        guard !cleaned.isEmpty else { return false }
        let ratio = Double(cleaned.count) / Double(max(raw.count, 1))
        return ratio > minimumLengthRatio && ratio < maximumLengthRatio
    }
}
