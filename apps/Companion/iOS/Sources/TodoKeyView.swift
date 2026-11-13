import SwiftUI
import TimbreCore
import TimbreReminders

/// The to-do key (GDR-0016, GDR-0026): hold, say it, it lands in the Timbre
/// list in Reminders with the date read on-device. Read the list back.
struct TodoKeyView: View {
    let model: CompanionModel
    @State private var live = ""
    @State private var held = false
    @State private var confirmation: String?
    @State private var problem: String?
    @State private var todos: [Todo] = []
    @State private var listName = ReminderStore.defaultListTitle
    @State private var streamTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(
                        "Say it — \"call the dentist Thursday\" — and it lands in Reminders, with the date read on your iPhone."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    Text(live.isEmpty ? (held ? "Listening…" : " ") : live)
                        .font(.body)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)

                    HoldToTalkButton(
                        title: "Hold and say a to-do", heldTitle: "Listening…", tint: Retro.sky, isHeld: held,
                        onPress: begin, onRelease: end)

                    if let confirmation {
                        Label(confirmation, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Retro.sky)
                            .font(.callout)
                    }
                    if let problem {
                        Text(problem).font(.caption).foregroundStyle(Retro.coral)
                    }

                    Divider()

                    HStack {
                        Text("Open in \(listName)").font(.headline)
                        Spacer()
                        Button("Read aloud") {
                            model.reader.read(TodoPhrasing.spokenList(todos, list: listName))
                        }
                        .buttonStyle(.bordered)
                        .tint(Retro.mustard)
                        .disabled(todos.isEmpty)
                    }
                    if todos.isEmpty {
                        Text("Nothing open.").foregroundStyle(.secondary).font(.callout)
                    }
                    ForEach(Array(todos.enumerated()), id: \.offset) { _, todo in
                        HStack(alignment: .firstTextBaseline) {
                            Text(todo.title)
                            Spacer()
                            if let due = todo.due {
                                Text(TodoPhrasing.when(due, hasTime: todo.hasTime))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.callout)
                    }
                }
                .padding(20)
            }
            .navigationTitle("To-do")
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    private func reload() async {
        if let (list, open) = try? await model.openTodos() {
            listName = list
            todos = open
        }
    }

    private func begin() {
        held = true
        live = ""
        confirmation = nil
        problem = nil
        streamTask?.cancel()
        streamTask = Task {
            guard await model.microphoneAllowed() else {
                problem = "Timbre needs the microphone for this. Settings › Privacy › Microphone."
                held = false
                return
            }
            do {
                let stream = try await model.beginListening()
                for await snapshot in stream { live = snapshot.text }
            } catch {
                problem = error.localizedDescription
                held = false
            }
        }
    }

    private func end() {
        guard held else { return }
        held = false
        Task {
            do {
                let spoken = try await model.endListening()
                guard !spoken.trimmingCharacters(in: .whitespaces).isEmpty else {
                    problem = "Nothing heard."
                    return
                }
                let (todo, list) = try await model.addTodo(spoken: spoken)
                confirmation = TodoPhrasing.confirmation(todo, list: list)
                await reload()
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}
