import Foundation

/// A selection split into the text worth transforming and the whitespace
/// around it.
///
/// People select sloppily — a trailing space, the newline at the end of a
/// paragraph. The model trims all of that, and pasting its answer back would
/// quietly join the paragraph to the next one. The frame goes back on exactly
/// as it came off.
nonisolated struct SelectionFrame: Equatable {
    let leading: String
    let core: String
    let trailing: String

    init(_ selection: String) {
        let leadingCount = selection.prefix(while: \.isWhitespace).count
        let remainder = selection.dropFirst(leadingCount)
        let trailingCount = remainder.reversed().prefix(while: \.isWhitespace).count

        leading = String(selection.prefix(leadingCount))
        core = String(remainder.dropLast(trailingCount))
        trailing = String(remainder.suffix(trailingCount))
    }

    func wrapping(_ replacement: String) -> String {
        leading + replacement + trailing
    }
}
