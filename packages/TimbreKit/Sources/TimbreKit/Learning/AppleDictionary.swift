import CoreServices
import Foundation

/// Apple's dictionary, on the Mac — the supplement GDR-0028 allows there.
/// The New Oxford American definition of a word, on-device, labelled as
/// Apple's on the card. Not redistributable and never bundled: a lookup at
/// the moment the card is shown, and nothing kept.
nonisolated enum AppleDictionary {

    struct Entry: Equatable, Sendable {
        let pronunciation: String?
        let text: String
    }

    static func lookup(_ term: String) -> Entry? {
        let range = CFRangeMake(0, (term as NSString).length)
        guard let raw = DCSCopyTextDefinition(nil, term as CFString, range)?.takeRetainedValue() else {
            return nil
        }
        return parse(raw as String, term: term)
    }

    /// The dictionary renders an entry as one text:
    /// `ephemeral | əˈfem(ə)rəl | adjective lasting for a very short time: …`.
    /// The pronunciation sits between the bars when there is one; the first
    /// paragraph is the senses, cut at a sentence end once it is long enough.
    static func parse(_ raw: String, term: String) -> Entry? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        var pronunciation: String?
        let parts = text.components(separatedBy: " | ")
        if parts.count >= 3, parts[0].lowercased() == term.lowercased() {
            pronunciation = parts[1].trimmingCharacters(in: .whitespaces)
            text = parts[2...].joined(separator: " | ")
        } else if text.lowercased().hasPrefix(term.lowercased()) {
            text = String(text.dropFirst(term.count)).trimmingCharacters(in: .whitespaces)
        }
        if let newline = text.firstIndex(where: \.isNewline) { text = String(text[..<newline]) }
        text = truncated(text.trimmingCharacters(in: .whitespaces), to: 240)
        return text.isEmpty ? nil : Entry(pronunciation: pronunciation, text: text)
    }

    static func truncated(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let head = text.prefix(limit)
        if let end = head.lastIndex(where: { ".;:".contains($0) }),
            head.distance(from: head.startIndex, to: end) > limit / 2
        {
            return String(head[...end])
        }
        if let space = head.lastIndex(of: " ") { return String(head[..<space]) + "…" }
        return String(head) + "…"
    }
}
