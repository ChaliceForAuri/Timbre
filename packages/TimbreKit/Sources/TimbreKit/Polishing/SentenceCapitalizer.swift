import Foundation

/// Capitalizes the first letter of the text and of each sentence after a
/// terminator or a line break. Deterministic and after the model, for the
/// same reason as the final full stop (ADR-0005, ADR-0011): measured, greedy
/// decoding left "the deploy went out this morning." lowercase five runs in
/// five, and sampling did so at random.
///
/// A word that carries its own casing — iPhone, macOS, eBay — is left alone,
/// and an abbreviation's dot (e.g., i.e., a.m.) does not end a sentence.
nonisolated enum SentenceCapitalizer {

    static func capitalized(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var characters = Array(text)
        var atSentenceStart = true
        var afterTerminator = false

        for index in characters.indices {
            let character = characters[index]

            if character.isNewline {
                result.append(character)
                atSentenceStart = true
                afterTerminator = false
                continue
            }
            if character.isWhitespace {
                result.append(character)
                if afterTerminator { atSentenceStart = true }
                continue
            }
            if character.isLetter {
                if atSentenceStart, shouldCapitalizeWord(startingAt: index, in: characters) {
                    characters[index] = Character(character.uppercased())
                }
                result.append(characters[index])
                atSentenceStart = false
                afterTerminator = false
                continue
            }
            if ".!?".contains(character) {
                result.append(character)
                afterTerminator = character != "." || !isAbbreviationDot(at: index, in: characters)
                continue
            }
            result.append(character)
            // Quotes, brackets and bullets carry a pending sentence start
            // through; anything else — a digit, a symbol — consumes it.
            if !"\"'“”‘’()[]•-–—".contains(character) {
                atSentenceStart = false
                afterTerminator = false
            }
        }
        return result
    }

    /// Whether the text opens with a capital, or with something that has no
    /// capital to give — a digit, or a word that carries its own casing.
    static func isCapitalizedAtStart(_ text: String) -> Bool {
        let characters = Array(text)
        guard let index = characters.firstIndex(where: { !$0.isWhitespace && !"\"'“”‘’([•-–—".contains($0) })
        else { return true }
        let first = characters[index]
        guard first.isLetter else { return true }
        return first.isUppercase || !shouldCapitalizeWord(startingAt: index, in: characters)
    }

    /// A lowercase word that contains an uppercase letter is cased on
    /// purpose: iPhone, macOS, eBay, iOS. Everything else gets a capital.
    private static func shouldCapitalizeWord(startingAt start: Int, in characters: [Character]) -> Bool {
        guard characters[start].isLowercase else { return false }
        var index = start + 1
        while index < characters.count, characters[index].isLetter || characters[index].isNumber {
            if characters[index].isUppercase { return false }
            index += 1
        }
        return true
    }

    /// "e.g." "i.e." "a.m." "U.S.": a single letter between dots.
    private static func isAbbreviationDot(at index: Int, in characters: [Character]) -> Bool {
        guard index >= 2 else { return false }
        return characters[index - 1].isLetter && characters[index - 2] == "."
    }
}
