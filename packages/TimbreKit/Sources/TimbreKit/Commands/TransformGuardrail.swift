import Foundation

/// Decides whether the model's answer to a command can be trusted with the
/// user's text. The rule for command mode is *never destroy the selection*:
/// anything that fails here leaves the text exactly as it was.
nonisolated enum TransformGuardrail {

    /// Past this the on-device model's context window is the limit, and it
    /// fails in ways that are slow and confusing. Refuse up front instead.
    static let maximumSelectionLength = 6000

    /// A "shortening" no shorter than what it was given — the model copying
    /// its input, or trimming a space. Not a failure: there was nothing to cut.
    static func isNoReduction(_ result: String, original: String) -> Bool {
        let result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let original = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return false }
        return Double(result.count) / Double(max(original.count, 1)) >= 0.95
    }

    static func accepts(_ result: String, for command: VoiceCommand, original: String) -> Bool {
        let result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let original = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return false }

        let ratio = Double(result.count) / Double(max(original.count, 1))
        switch command {
        case .fix:
            // A fix moves a few characters. A large change is a rewrite or a
            // refusal. The absolute slack keeps "u r" → "you are" legal.
            return abs(result.count - original.count) <= 12 || (ratio > 0.7 && ratio < 1.4)
        case .shorten:
            // Noticeably shorter — trimming a trailing space is not a
            // shortening — but still the text rather than a one-word summary.
            return ratio < 0.95 && ratio > 0.15
        case .explain:
            // Length is the trimmer's business. What cannot be fixed after
            // the fact is an echo: measured, the model sometimes answers
            // "API" with "API".
            return TextMatch.normalized(result) != TextMatch.normalized(original)
        }
    }
}
