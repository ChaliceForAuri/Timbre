import SwiftUI
import TimbreCore
import TimbreSpeech

/// Spell it (GDR-0023, decision 5): the meaning is shown — or the word is
/// read aloud when it has none — the user holds the button, says the word
/// and spells it, and the check reads the letters. Deterministic; no model.
struct SpellItView: View {
    let model: CompanionModel
    @State private var queue: [LibraryEntry] = []
    @State private var index = 0
    @State private var live = ""
    @State private var held = false
    @State private var verdict: SpellVerdict?
    @State private var problem: String?
    @State private var streamTask: Task<Void, Never>?

    private var current: LibraryEntry? { queue.indices.contains(index) ? queue[index] : nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let entry = current {
                    round(entry)
                } else {
                    ContentUnavailableView(
                        "Nothing to practise", systemImage: "textformat.abc",
                        description: Text(
                            "Words come here as they fade. Add a few, or wait for a word to be due.")
                    )
                    .padding(.top, 40)
                }
            }
            .navigationTitle("Spell it")
            .task { queue = model.practiceQueue() }
        }
    }

    private func round(_ entry: LibraryEntry) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(index + 1) of \(queue.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                if let meaning = entry.meaning {
                    Text(meaning)
                        .font(.title3)
                    Text("Say the word, then spell it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Listen, then spell it.")
                        .font(.title3)
                    Button {
                        model.reader.read(entry.term)
                    } label: {
                        Label("Hear the word", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(.bordered)
                    .tint(Retro.mustard)
                }
            }

            if let verdict {
                result(verdict, for: entry)
            } else {
                Text(live.isEmpty ? (held ? "Listening…" : " ") : live)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                HoldToTalkButton(
                    title: "Hold and spell it", heldTitle: "Listening…", tint: Retro.lilac, isHeld: held,
                    onPress: { begin(entry) }, onRelease: { end(entry) })
                if let problem {
                    Text(problem).font(.caption).foregroundStyle(Retro.coral)
                }
            }
        }
        .padding(20)
    }

    private func result(_ verdict: SpellVerdict, for entry: LibraryEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: verdict.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(verdict.passed ? Retro.mint : Retro.coral)
                Text(verdict.passed ? "Spelled it." : "Not quite.")
                    .font(.title3.weight(.semibold))
            }
            Text(spaced(verdict.heard.isEmpty ? "nothing heard" : verdict.heard))
                .font(.body.monospaced())
            if !verdict.passed {
                Text("It is \(spaced(verdict.expected)).")
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }
            Button(index + 1 < queue.count ? "Next" : "Done") {
                self.verdict = nil
                live = ""
                problem = nil
                index += 1
            }
            .buttonStyle(.borderedProminent)
            .tint(Retro.lilac)
        }
        .sensoryFeedback(verdict.passed ? .success : .error, trigger: verdict)
    }

    private func spaced(_ letters: String) -> String {
        letters.map { String($0) }.joined(separator: " ")
    }

    private func begin(_ entry: LibraryEntry) {
        held = true
        live = ""
        problem = nil
        streamTask?.cancel()
        streamTask = Task {
            guard await model.microphoneAllowed() else {
                problem = "Timbre needs the microphone for this. Settings › Privacy › Microphone."
                held = false
                return
            }
            do {
                let stream = try await model.beginListening(vocabulary: [entry.term])
                for await snapshot in stream { live = snapshot.text }
            } catch {
                problem = error.localizedDescription
                held = false
            }
        }
    }

    private func end(_ entry: LibraryEntry) {
        guard held else { return }
        held = false
        Task {
            do {
                let spoken = try await model.endListening()
                let check = SpellCheck.check(entry.term, against: spoken)
                model.record(check, for: entry)
                verdict = check
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}
