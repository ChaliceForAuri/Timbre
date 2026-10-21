import SwiftUI
import TimbreCore

/// One scrolling screen: the to-do key first, because it is why the Watch
/// exists (GDR-0026); then today's word; then the small things.
struct WatchRootView: View {
    let model: WatchModel
    @State private var confirmation: String?
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextFieldLink(prompt: Text("The to-do")) {
                        Label("Say a to-do", systemImage: "checklist")
                            .frame(maxWidth: .infinity)
                    } onSubmit: { text in
                        Task { await add(text) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.27, green: 0.65, blue: 0.82))
                    .handGestureShortcut(.primaryAction)

                    if let filed = model.lastFiled {
                        Text(filed).font(.caption).foregroundStyle(.secondary)
                    } else if let confirmation {
                        Text(confirmation).font(.caption).foregroundStyle(.secondary)
                    }
                    if !model.relay.pending.isEmpty {
                        Text("\(model.relay.pending.items.count) waiting for your iPhone")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let problem {
                        Text(problem).font(.caption).foregroundStyle(.red)
                    }

                    todayCard

                    NavigationLink {
                        WatchSpellItView(model: model)
                    } label: {
                        Label("Spell it", systemImage: "textformat.abc")
                    }

                    TextFieldLink(prompt: Text("The word")) {
                        Label("Heard a word", systemImage: "plus")
                    } onSubmit: { word in
                        model.addHeardWord(word)
                        confirmation = "Banked \(word)."
                    }
                }
            }
            .navigationTitle("Timbre")
            .task { model.refresh() }
        }
    }

    @ViewBuilder
    private var todayCard: some View {
        if let card = model.card {
            VStack(alignment: .leading, spacing: 4) {
                Text("Word of the day")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(card.term)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                if let meaning = card.meanings.first {
                    Text(meaning.text).font(.caption).lineLimit(3)
                }
                Text(card.metToday ? "Met today" : card.why)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        } else {
            Text("Nothing due today.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func add(_ text: String) async {
        problem = nil
        let todo = model.addTodo(spoken: text)
        confirmation = "\(todo.title) — on its way to Reminders through your iPhone."
    }
}

/// Spell it on the wrist: the meaning shown, the word said and spelled into
/// the system's dictation, the letters checked. No model (GDR-0026).
struct WatchSpellItView: View {
    let model: WatchModel
    @State private var queue: [LibraryEntry] = []
    @State private var index = 0
    @State private var verdict: SpellVerdict?

    private var current: LibraryEntry? { queue.indices.contains(index) ? queue[index] : nil }

    var body: some View {
        ScrollView {
            if let entry = current {
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.meaning ?? "Spell: \(entry.term)")
                        .font(.body)
                    if let verdict {
                        Text(verdict.passed ? "Spelled it." : "Not quite: \(verdict.expected)")
                            .font(.caption)
                            .foregroundStyle(verdict.passed ? .green : .red)
                        Button(index + 1 < queue.count ? "Next" : "Done") {
                            self.verdict = nil
                            index += 1
                        }
                    } else {
                        TextFieldLink(prompt: Text("Say it, then spell it")) {
                            Label("Spell it", systemImage: "mic")
                        } onSubmit: { spoken in
                            verdict = model.spell(spoken, for: entry)
                        }
                    }
                }
            } else {
                Text("Nothing to practise yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Spell it")
        .task { queue = model.practiceQueue() }
    }
}
