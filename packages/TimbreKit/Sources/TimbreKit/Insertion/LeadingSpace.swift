/// Whether an insertion needs a space in front of it. Two dictations in a
/// row land as "better.Thank you." unless the second one starts with the
/// space the user would have typed; Apple's dictation adds it by looking at
/// the character before the caret. Timbre does the same when the field can
/// be read (live typing), and falls back to a rule of thumb when it cannot.
nonisolated enum LeadingSpace {

    /// From the character before the caret: nothing, whitespace, or an
    /// opening bracket or quote means no space; anything else means one.
    static func needed(before character: Character?) -> Bool {
        guard let character else { return false }
        if character.isWhitespace || character.isNewline { return false }
        return !"([{\"'“‘«".contains(character)
    }

    /// How long after an insertion the next one is assumed to follow it.
    static let window: Duration = .seconds(20)

    /// Without a readable field: the last insertion was into the same app a
    /// moment ago and ended a sentence, so the caret is almost certainly
    /// right behind it.
    static func likelyNeeded(
        lastApp: String?, lastText: String, lastAt: ContinuousClock.Instant,
        app: String?, now: ContinuousClock.Instant
    ) -> Bool {
        guard let lastApp, lastApp == app, now - lastAt <= window, let end = lastText.last else {
            return false
        }
        return ".!?…".contains(end)
    }
}
