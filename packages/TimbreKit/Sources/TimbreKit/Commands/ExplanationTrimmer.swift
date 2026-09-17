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
