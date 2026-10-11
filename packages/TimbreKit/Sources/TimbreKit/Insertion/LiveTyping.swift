import Foundation

/// Decides what to type while the user is still talking, and what is left
/// to type when they stop (GDR-0018). Pure bookkeeping over the transcript's
/// confirmed half, so it can be tested without a microphone.
///
/// The confirmed text only ever grows, so each snapshot's new tail is what
/// gets typed. The very first delta loses its leading whitespace — the
/// model's chunks start with a space, and the field should not.
nonisolated struct LiveTyping {

    /// Exactly what has been typed into the app so far.
    private(set) var typed = ""
    /// The confirmed text consumed so far, untrimmed, for prefix matching.
    private var consumed = ""

    /// The text to type now, given everything the model has confirmed.
    /// Empty when nothing new has been confirmed.
    mutating func delta(for finalized: String) -> String {
        guard finalized.hasPrefix(consumed) else {
            // Confirmed text is documented never to change; if it ever did,
            // typing more would corrupt the field. Type nothing and let the
            // release path replace the whole run.
            return ""
        }
        var delta = String(finalized.dropFirst(consumed.count))
        consumed = finalized
        if typed.isEmpty {
            delta = String(delta.drop(while: \.isWhitespace))
        }
        typed += delta
        return delta
    }

    /// What the full transcript still owes the field once the model has
    /// finished, or nil when the transcript does not extend what was typed
    /// — in which case the run must be replaced wholesale, not appended to.
    func remainder(of transcript: String) -> String? {
        let base = String(typed.reversed().drop(while: \.isWhitespace).reversed())
        let trailing = typed.count - base.count
        guard transcript.hasPrefix(base) else { return nil }
        let rest = transcript.dropFirst(base.count)
        // The field already has the trailing whitespace the last chunk carried.
        return String(rest.dropFirst(min(trailing, rest.prefix(while: \.isWhitespace).count)))
    }

    /// Notes text typed by the release path, so `typed` stays exact.
    mutating func didType(_ text: String) {
        typed += text
    }
}

/// Whether the text now in the field is the run Timbre typed — close enough
/// that replacing it is safe. Apps autocorrect, capitalise and expand as one
/// types, so the match is approximate: letters and digits only, case
/// ignored, and a fifth of the characters allowed to differ.
nonisolated enum ReplacementCheck {

    static func matches(field: String, typed: String) -> Bool {
        let a = normalized(field)
        let b = normalized(typed)
        guard !b.isEmpty else { return false }
        let allowance = max(2, b.count / 5)
        // Cheap bound before the quadratic distance: lengths that differ by
        // more than the allowance cannot be within it.
        guard abs(a.count - b.count) <= allowance else { return false }
        return EditDistance.between(a, b) <= allowance
    }

    private static func normalized(_ text: String) -> String {
        var out = ""
        var pendingSpace = false
        for scalar in text.lowercased().unicodeScalars {
            if scalar.properties.isAlphabetic || scalar.properties.numericType != nil {
                if pendingSpace, !out.isEmpty { out.append(" ") }
                pendingSpace = false
                out.unicodeScalars.append(scalar)
            } else {
                pendingSpace = true
            }
        }
        return out
    }
}
