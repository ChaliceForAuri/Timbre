import SwiftUI
import TimbreCore

/// Today's word (GDR-0027): the facts labelled by source, why this word
/// today, whether it has been met, and the two things to do with it — hear
/// it, and spell it.
struct TodayView: View {
    let model: CompanionModel
    @Binding var selection: Tab

    var body: some View {
        NavigationStack {
            ScrollView {
                if let card = model.card {
                    content(card)
                } else {
                    nothingDue
                }
            }
            .navigationTitle("Today")
            .refreshable { model.refresh() }
        }
    }

    private func content(_ card: WordCard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Word of the day")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(card.term)
                    .font(.system(size: 38, weight: .semibold, design: .serif))
                HStack(spacing: 8) {
                    if let pronunciation = card.pronunciation {
                        Text(pronunciation).font(.callout).foregroundStyle(.secondary)
                    }
                    if let partOfSpeech = card.partOfSpeech {
                        Text(partOfSpeech).font(.callout.italic()).foregroundStyle(.secondary)
                    }
                    if let kind = card.kind { SourceTag(text: kind.rawValue) }
                }
            }

            if card.meanings.isEmpty, card.origin == nil {
                Text("No meaning yet. Add one in the Library, or let the day teach you.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(card.meanings.enumerated()), id: \.offset) { _, line in labelled(line) }
            if let origin = card.origin { labelled(origin, heading: "Origin") }
            if let example = card.example { labelled(example, heading: "In a sentence") }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(card.why).font(.caption).foregroundStyle(.secondary)
                let streak = Streaks.current(in: model.library.events, on: Date())
                if streak > 0 {
                    Text(streak == 1 ? "A 1-day streak." : "A \(streak)-day streak.")
                        .font(.caption)
                        .foregroundStyle(Retro.lilac)
                }
                HStack(spacing: 8) {
                    if let strength = card.strength { StrengthBar(strength: strength) }
                    Text(card.metToday ? "Met today." : "Not met yet today.")
                        .font(.caption)
                        .foregroundStyle(card.metToday ? Retro.mint : .secondary)
                }
            }

            HStack(spacing: 12) {
                Button {
                    model.readCard()
                } label: {
                    Label("Hear it", systemImage: "speaker.wave.2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Retro.mustard)
                .foregroundStyle(.black)
                Button {
                    selection = .practice
                } label: {
                    Label("Practise", systemImage: "textformat.abc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Retro.lilac)
            }
            .padding(.top, 4)
        }
        .padding(20)
    }

    private var nothingDue: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing due today")
                .font(.title3.weight(.semibold))
            Text(
                "Your Library has no word that has faded far enough to ask for. Add a word you heard, "
                    + "or teach one on the Mac, and it will come round in a few days."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            Button("Add a word") { selection = .library }
                .buttonStyle(.borderedProminent)
                .tint(Retro.mint)
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private func labelled(_ line: WordCard.Line, heading: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if let heading {
                    Text(heading).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
                SourceTag(text: line.source.label)
            }
            Text(line.text)
                .font(.body)
                .textSelection(.enabled)
        }
    }
}
