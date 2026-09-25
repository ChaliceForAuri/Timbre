import Foundation

/// Keeps an explanation to what fits a glance.
///
/// Asked for two sentences, the model measured at five to eight. Rejecting a
/// correct answer for being long would throw away the useful part, and an
/// explanation is only ever shown, never pasted — so cutting it to its
/// opening sentences is safe in a way that cutting a replacement never is.
nonisolated enum ExplanationTrimmer {

    static let maximumSentences = 3
    static let maximumCharacters = 420

    /// Whether a partial answer already holds everything `trimmed` will
    /// keep: a sentence past the maximum has begun, or it is past the length
    /// limit. Generation stops there. A cap, not a speed-up: with the current
    /// prompt the model ends on its own within two sentences (measured: 641 ms
    /// with the stop, 640 ms without). It bounds the run the day it doesn't —
    /// the first prompt drew eight sentences.
    static func isFull(_ partial: String) -> Bool {
        if partial.count > maximumCharacters { return true }
        var sentences = 0
        partial.enumerateSubstrings(in: partial.startIndex..., options: .bySentences) { _, _, _, stop in
            sentences += 1
            if sentences > maximumSentences { stop = true }
        }
        return sentences > maximumSentences
    }

    static func trimmed(_ text: String) -> String {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, stop in
            guard let sentence else { return }
            let candidate = sentences.joined() + sentence
            let fits = candidate.trimmingCharacters(in: .whitespaces).count <= maximumCharacters
            if sentences.count < maximumSentences, fits || sentences.isEmpty {
                sentences.append(sentence)
            } else {
                stop = true
            }
        }

        let kept = sentences.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        guard kept.count > maximumCharacters else { return kept }

        // One enormous sentence: cut at a word, and say that it was cut.
        let cut = kept.prefix(maximumCharacters)
        let end = cut.lastIndex(where: \.isWhitespace) ?? cut.endIndex
        return cut[..<end].trimmingCharacters(in: .whitespaces) + "…"
    }
}
