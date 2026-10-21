import Foundation

/// What Spell it heard, letter by letter, against the word.
nonisolated public struct SpellVerdict: Equatable, Sendable {
    public let passed: Bool
    /// The letters that were heard, joined.
    public let heard: String
    /// The letters of the word, lowercased, nothing else.
    public let expected: String
}

/// Spell it's check (GDR-0023, decision 5): deterministic, from the text the
/// recogniser returns, so it runs on the Watch with no model. The user says
/// the word, then spells it; the check reads the spelling.
///
/// It tolerates what recognisers do to spelled letters: letter names ("tee",
/// "double-u"), "double t", "capital A", dots and hyphens between letters,
/// and a run of letters glued into one token ("SEPERATE"). It never guesses
/// a letter that was not heard. Its one blind spot is honest: a plain word
/// said twice looks the same as a spelling the recogniser glued, and passes.
nonisolated public enum SpellCheck {

    public static func check(_ word: String, against spoken: String) -> SpellVerdict {
        let expected = letters(of: word)
        var tokens = tokens(of: spoken)

        // The word itself, said first, is not part of the spelling — even when
        // the recogniser splits it ("can't" arrives as "can" and "t"). When the
        // whole utterance is the word, it counts only if it came letter by
        // letter, or the word is an acronym, which is its letters.
        let isAcronym = expected.count > 1 && word.filter(\.isLetter).allSatisfy(\.isUppercase)
        var prefix = ""
        for (count, token) in tokens.enumerated() {
            prefix += letters(of: token)
            if prefix == expected {
                let consumedAll = count + 1 == tokens.count
                let letterByLetter = tokens[...count].allSatisfy { letters(of: $0).count == 1 }
                if !consumedAll || !(letterByLetter || isAcronym) {
                    tokens.removeFirst(count + 1)
                }
                break
            }
            if prefix.count >= expected.count || !expected.hasPrefix(prefix) { break }
        }

        var heard = ""
        var repeats = 1
        for token in tokens {
            switch token {
            case "double":
                repeats = 2
                continue
            case "triple":
                repeats = 3
                continue
            case "capital", "uppercase", "lowercase", "small", "big", "letter":
                continue
            default:
                break
            }
            var piece: String?
            if repeats == 2, token == "u" || token == "you" {
                // "double u" is W, not two U's.
                piece = "w"
                repeats = 1
            } else if token.count == 1, token.first?.isLetter == true {
                piece = token
            } else if let named = letterNames[token] {
                piece = named
            } else if token.count > 1, token.allSatisfy(\.isLetter) {
                // A spelling the recogniser glued together.
                piece = token
                repeats = 1
            }
            if let piece {
                heard += String(repeating: piece, count: repeats)
            }
            repeats = 1
        }
        return SpellVerdict(passed: !heard.isEmpty && heard == expected, heard: heard, expected: expected)
    }

    static func letters(of text: String) -> String {
        text.lowercased().filter(\.isLetter)
    }

    static func tokens(of spoken: String) -> [String] {
        String(spoken.lowercased().map { "-–—.,;:!?()\"'".contains($0) ? " " : $0 })
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    /// How a recogniser writes a letter said on its own.
    static let letterNames: [String: String] = [
        "ay": "a", "eh": "a",
        "bee": "b", "be": "b",
        "see": "c", "sea": "c", "cee": "c",
        "dee": "d", "de": "d",
        "ee": "e",
        "ef": "f", "eff": "f",
        "gee": "g", "jee": "g",
        "aitch": "h", "aych": "h",
        "eye": "i",
        "jay": "j",
        "kay": "k",
        "el": "l", "ell": "l",
        "em": "m",
        "en": "n",
        "oh": "o",
        "pee": "p", "pea": "p",
        "cue": "q", "queue": "q", "kyu": "q",
        "ar": "r", "are": "r",
        "es": "s", "ess": "s",
        "tee": "t", "tea": "t",
        "you": "u", "yu": "u",
        "vee": "v",
        "doubleu": "w", "doubleyou": "w",
        "ex": "x",
        "why": "y", "wy": "y",
        "zed": "z", "zee": "z",
    ]
}
