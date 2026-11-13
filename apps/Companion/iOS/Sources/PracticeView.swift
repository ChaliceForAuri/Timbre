import SwiftUI
import TimbreCore
import TimbreModel
import TimbreSpeech

/// Practice (GDR-0023, decision 5): the drill today's plan gives each due
/// word — Spell it, Say it, Explain it — a hold-to-talk button, and the
/// verdict with its reason. Spell it is checked by letters; Say it by the
/// model inside its guardrail; Explain it by the words first and the model
/// only when they cannot tell. Without the model, only what needs no judge
/// is asked (GDR-0026).
struct PracticeView: View {
    let model: CompanionModel
    @State private var queue: [LibraryEntry] = []
    @State private var index = 0
    @State private var live = ""
    @State private var held = false
    @State private var checking = false
    @State private var verdict: DrillVerdict?
    @State private var heard = ""
    @State private var problem: String?
    @State private var streamTask: Task<Void, Never>?

    private var current: LibraryEntry? { queue.indices.contains(index) ? queue[index] : nil }
    private var drill: Drill? {
        current.map { DrillPlanner.drill(for: $0, on: Date(), withModel: model.modelAvailability.isReady) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let entry = current, let drill {
                    round(entry, drill: drill)
                } else {
                    finished
                }
            }
            .navigationTitle("Practice")
            .task { queue = model.practiceQueue() }
        }
    }

    private func round(_ entry: LibraryEntry, drill: Drill) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(drill.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(index + 1) of \(queue.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            prompt(entry, drill: drill)

            if let verdict {
                result(verdict)
            } else {
                Text(live.isEmpty ? (held ? "Listening…" : (checking ? "Checking…" : " ")) : live)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                HoldToTalkButton(
                    title: checking ? "Checking…" : "Hold and speak", heldTitle: "Listening…",
                    tint: Retro.lilac,
                    isHeld: held, onPress: { begin(entry) }, onRelease: { end(entry, drill: drill) })
                if let problem {
                    Text(problem).font(.caption).foregroundStyle(Retro.coral)
                }
            }
        }
        .padding(20)
    }

    private func prompt(_ entry: LibraryEntry, drill: Drill) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch drill {
            case .spellIt:
                if let meaning = entry.meaning {
                    Text(meaning).font(.title3)
                    Text("Say the word, then spell it.").font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("Listen, then say it and spell it.").font(.title3)
                    Button {
                        model.reader.read(entry.term)
                    } label: {
                        Label("Hear the word", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(.bordered)
                    .tint(Retro.mustard)
                }
            case .sayIt:
                Text(entry.term).font(.system(size: 32, weight: .semibold, design: .serif))
                if let meaning = entry.meaning {
                    Text(meaning).font(.callout).foregroundStyle(.secondary)
                }
                Text("Use it in a sentence.").font(.callout).foregroundStyle(.secondary)
            case .explainIt:
                Text(entry.term).font(.system(size: 32, weight: .semibold, design: .serif))
                Text("What does it mean?").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func result(_ verdict: DrillVerdict) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: verdict.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(verdict.passed ? Retro.mint : Retro.coral)
                Text(verdict.passed ? "Yes." : "Not quite.")
                    .font(.title3.weight(.semibold))
            }
            Text(verdict.reason)
            if !heard.isEmpty {
                Text("You said: \(heard)").font(.caption).foregroundStyle(.secondary)
            }
            Button(index + 1 < queue.count ? "Next" : "Done") {
                self.verdict = nil
                live = ""
                heard = ""
                problem = nil
                index += 1
            }
            .buttonStyle(.borderedProminent)
            .tint(Retro.lilac)
        }
        .sensoryFeedback(verdict.passed ? .success : .error, trigger: verdict)
    }

    private var finished: some View {
        ContentUnavailableView(
            queue.isEmpty ? "Nothing to practise" : "That is the lot",
            systemImage: "textformat.abc",
            description: Text(
                queue.isEmpty
                    ? "Words come here as they fade, weakest first. Add a few and come back."
                    : "Every due word has had its minute. Tomorrow brings the next.")
        )
        .padding(.top, 40)
    }

    private func begin(_ entry: LibraryEntry) {
        guard !checking else { return }
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

    private func end(_ entry: LibraryEntry, drill: Drill) {
        guard held else { return }
        held = false
        checking = true
        Task {
            defer { checking = false }
            do {
                let spoken = try await model.endListening()
                heard = spoken
                let outcome = await model.verdict(for: drill, entry: entry, spoken: spoken)
                model.record(outcome, drill: drill, for: entry)
                verdict = outcome
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}
