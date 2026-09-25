import AppKit
import Foundation

/// Fix without Apple Intelligence: macOS's own spell checker, word by word
/// (GDR-0015). Only clear corrections — the checker's single best guess for a
/// word it flags — and nothing else: no grammar, no rephrasing. Tidy does the
/// same on a Mac without the model, and it is a great deal better than the
/// taught corrections alone.
enum SpellingFallback {

    /// `keeping` is the user's vocabulary: a taught word is never "corrected".
    /// Neither is a capitalised word inside a sentence — a name the checker
    /// has not heard of, which is most names.
    static func corrected(_ text: String, keeping vocabulary: [String] = [], language: String = "en")
        -> String
    {
        // Literals first: the checker would otherwise "fix" the eng in
        // #eng-releases. Its placeholders contain no letters to flag.
        let masked = LiteralGuard.mask(text)
        let spelled = correctedWords(
            in: masked.text, keeping: Set(vocabulary.map { $0.lowercased() }), language: language)
        return LiteralGuard.restore(spelled, from: masked, requireAll: true) ?? text
    }

    private static func correctedWords(in text: String, keeping vocabulary: Set<String>, language: String)
        -> String
    {
        let checker = NSSpellChecker.shared
        let tag = NSSpellChecker.uniqueSpellDocumentTag()
        defer { checker.closeSpellDocument(withTag: tag) }

        var result = text as NSString
        var searchFrom = 0
        while searchFrom < result.length {
            let misspelled = checker.checkSpelling(
                of: result as String, startingAt: searchFrom, language: language, wrap: false,
                inSpellDocumentWithTag: tag, wordCount: nil)
            guard misspelled.location != NSNotFound, misspelled.length > 0 else { break }
            let word = result.substring(with: misspelled)
            if let fix = checker.correction(
                forWordRange: misspelled, in: result as String, language: language,
                inSpellDocumentWithTag: tag),
                fix != word, !LiteralGuard.mask(word).literals.contains(word)
            {
                result = result.replacingCharacters(in: misspelled, with: fix) as NSString
                searchFrom = misspelled.location + (fix as NSString).length
            } else {
                searchFrom = misspelled.location + misspelled.length
            }
        }
        return result as String
    }
}

extension SpellingFallback {
    /// A capital letter that is not the first of a sentence: a name.
    fileprivate static func isCapitalisedMidSentence(_ text: NSString, at range: NSRange) -> Bool {
        let word = text.substring(with: range)
        guard let first = word.first, first.isUppercase, range.location > 0 else { return false }
        let before = text.substring(to: range.location).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = before.last else { return false }
        return !".!?".contains(last)
    }
}

/// Damerau–Levenshtein distance, small strings only.
nonisolated enum EditDistance {
    static func between(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1)
                }
            }
        }
        return d[a.count][b.count]
    }
}
