import SwiftUI

/// The retro palette (GDR-0017): keycap grey for the ground, and one colour
/// per gesture. The same hues as the site's keycaps, as sRGB.
enum Retro {
    /// Dictate, and here: speak.
    static let mint = Color(red: 0.28, green: 0.81, blue: 0.64)
    /// Read aloud.
    static let mustard = Color(red: 0.90, green: 0.77, blue: 0.27)
    /// The to-do key.
    static let sky = Color(red: 0.27, green: 0.65, blue: 0.82)
    /// A refusal, a miss.
    static let coral = Color(red: 0.88, green: 0.34, blue: 0.34)
    /// Practice.
    static let lilac = Color(red: 0.63, green: 0.43, blue: 0.86)
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

/// A word's strength (ADR-0014) as a short bar: the chance of recalling it
/// now. Coral below the target, so a due word reads as due.
struct StrengthBar: View {
    let strength: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(strength < 0.9 ? Retro.coral : Retro.mint)
                    .frame(width: max(4, proxy.size.width * strength))
            }
        }
        .frame(width: 56, height: 6)
        .accessibilityLabel("Strength \(Int((strength * 100).rounded())) percent")
    }
}
