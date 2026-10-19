import SwiftUI

/// Rows in a quiet box, or a line saying there are none. Not a `List`:
/// scrolling lists inside a scrolling tab fight over the scroll wheel.
struct RowList<Content: View>: View {
    let isEmpty: Bool
    var emptyText = "Nothing here yet."
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEmpty {
                Text(emptyText)
                    .foregroundStyle(.tertiary)
            } else {
                content
            }
        }
        .font(.callout)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
    }
}

/// A word's strength (ADR-0014) as a short bar: the chance of recalling it
/// now. Red below the target, so a due word reads as due.
struct StrengthBar: View {
    let strength: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(strength < 0.9 ? Color.orange : Color.green)
                    .frame(width: max(4, proxy.size.width * strength))
            }
        }
        .frame(width: 56, height: 6)
        .help("\(Int((strength * 100).rounded()))% likely to recall it now")
        .accessibilityLabel("Strength \(Int((strength * 100).rounded())) percent")
    }
}

/// A small label naming where a line on a card came from (GDR-0027).
struct SourceTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
            .foregroundStyle(.secondary)
    }
}
