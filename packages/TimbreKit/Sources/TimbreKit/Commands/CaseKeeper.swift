import Foundation

/// A fix on a fragment keeps the fragment's case. "teh" becomes "the", not
/// "The": a selected word is not a sentence, and capitalising it moves where
/// the sentence appears to begin (Tidy hit the same bug and shipped the same
/// rule). A fragment is short, starts lowercase and ends without a full stop.
nonisolated enum CaseKeeper {

    static let fragmentWordLimit = 3

    static func isFragment(_ original: String) -> Bool {
        let trimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, first.isLowercase else { return false }
        guard let last = trimmed.last, !".!?".contains(last) else { return false }
        return trimmed.split(whereSeparator: \.isWhitespace).count <= fragmentWordLimit
    }

    /// `result` with its first letter lowered, when `original` was a fragment.
    static func keepingCase(of original: String, in result: String) -> String {
        guard isFragment(original), let first = result.first, first.isUppercase else { return result }
        // A result that became a cased word — "iPhone" — is the model's
        // correction, not a capitalisation.
        let word = result.prefix { $0.isLetter }
        guard word.dropFirst().allSatisfy({ !$0.isUppercase }) else { return result }
        return first.lowercased() + result.dropFirst()
    }
}
