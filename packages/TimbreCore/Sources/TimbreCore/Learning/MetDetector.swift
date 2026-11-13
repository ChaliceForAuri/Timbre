import Foundation

/// Whether today's word turned up in what the user just said (GDR-0027).
/// Whole word or phrase, case ignored, any whitespace between the words —
/// the correction table's own notion of a match, run on the polished text
/// after corrections, so a taught mis-hearing still counts as meeting the
/// word. Looks; never keeps the text.
nonisolated public enum MetDetector {

    public static func contains(_ term: String, in text: String) -> Bool {
        guard let pattern = CorrectionTable.pattern(matching: term) else { return false }
        return text.contains(pattern)
    }
}
