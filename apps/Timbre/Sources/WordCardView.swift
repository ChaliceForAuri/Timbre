import SwiftUI
import TimbreKit

/// Today's word (GDR-0027): the facts, each labelled by where it came from,
/// the line saying why this word today, and whether it has been met. One
/// window, opened from the menu bar or the morning notification.
struct WordCardView: View {
    let wordOfTheDay: WordOfTheDay
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            if let card = wordOfTheDay.card {
                content(card)
            } else {
                nothingDue
            }
        }
        .frame(width: 440)
        .padding(24)
    }

    private func content(_ card: WordCard) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Word of the day")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(card.term)
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                HStack(spacing: 8) {
                    if let pronunciation = card.pronunciation {
                        Text(pronunciation)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    if let partOfSpeech = card.partOfSpeech {
                        Text(partOfSpeech)
                            .font(.callout.italic())
                            .foregroundStyle(.secondary)
                    }
                    if let kind = card.kind {
                        SourceTag(text: kind.rawValue)
                    }
                }
            }

            if card.meanings.isEmpty, card.origin == nil {
                Text("No meaning yet. Add one in Settings › Library, or let the day teach you.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(card.meanings.enumerated()), id: \.offset) { _, line in
                labelled(line)
            }
            if let origin = card.origin {
                labelled(origin, heading: "Origin")
            }
            if let example = card.example {
                labelled(example, heading: "In a sentence")
            }

            Divider()

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.why)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        if let strength = card.strength {
                            StrengthBar(strength: strength)
                        }
                        Text(
                            card.metToday
                                ? "Met today — say it and it counts."
                                : "Not met yet today. Say it in a dictation and it counts."
                        )
                        .font(.caption)
                        .foregroundStyle(card.metToday ? Color.green : .secondary)
                    }
                }
                Spacer()
                Button("Read Aloud") { wordOfTheDay.read() }
            }
        }
    }

    private var nothingDue: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing due today")
                .font(.title3.weight(.semibold))
            Text(
                "Your Library has no word that has faded far enough to ask for. Teach one — hold right ⌘ on a "
                    + "word and say explain, or add it in Settings › Library — and it will come round in a few days."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings › Library") {
                NSApp.activate()
                openSettings()
            }
        }
    }

    private func labelled(_ line: WordCard.Line, heading: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if let heading {
                    Text(heading)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                SourceTag(text: line.source.label)
            }
            Text(line.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}
