import AppIntents
import TimbreCore

/// The Action Button's intent (GDR-0026): press, say the to-do, done.
struct AddTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Say a to-do"
    static let description = IntentDescription(
        "Adds a to-do to the Timbre list in Reminders, with the date read on the Watch.")

    @Parameter(title: "To-do", requestValueDialog: "What's the to-do?")
    var text: String

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let todo = WatchModel.shared.addTodo(spoken: text)
        return .result(
            dialog: IntentDialog(
                stringLiteral: "\(todo.title) — on its way to Reminders through your iPhone."))
    }
}

struct TimbreWatchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: ["Say a to-do in \(.applicationName)", "Add a to-do in \(.applicationName)"],
            shortTitle: "Say a to-do",
            systemImageName: "checklist"
        )
    }
}
