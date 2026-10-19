import AppIntents
import TimbreCore
import TimbreReminders

/// What Siri, Shortcuts, Spotlight and the Action Button can ask of Timbre
/// (GDR-0026). Each intent uses the app's own model, so a word added by
/// Siri is in the list the screen is showing.

struct AddWordIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a word to the Library"
    static let description = IntentDescription("Banks a word you heard, with no meaning yet.")

    @Parameter(title: "Word", requestValueDialog: "What's the word?")
    var word: String

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = CompanionModel.shared
        model.library.add(word, how: .dictated, app: "Siri")
        return .result(dialog: "Added \(word) to your Library.")
    }
}

struct AddTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Say a to-do"
    static let description = IntentDescription(
        "Adds a to-do to the Timbre list in Reminders, with the date read on-device.")

    @Parameter(title: "To-do", requestValueDialog: "What's the to-do?")
    var text: String

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let (todo, list) = try await CompanionModel.shared.addTodo(spoken: text)
        return .result(dialog: IntentDialog(stringLiteral: TodoPhrasing.confirmation(todo, list: list)))
    }
}

struct WordOfTheDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Word of the day"
    static let description = IntentDescription("Today's word from your Library.")

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = CompanionModel.shared
        guard
            let card = model.card
                ?? (model.library.wordOfTheDay(bundled: BundledLists.all).map {
                    WordCard(pick: $0, entry: nil)
                })
        else {
            return .result(dialog: "Nothing is due today. Add a word and it will come round in a few days.")
        }
        return .result(dialog: IntentDialog(stringLiteral: "Today's word is \(card.summary)."))
    }
}

struct TimbreShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: ["Say a to-do in \(.applicationName)", "Add a to-do in \(.applicationName)"],
            shortTitle: "Say a to-do",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: WordOfTheDayIntent(),
            phrases: ["What's my word of the day in \(.applicationName)"],
            shortTitle: "Word of the day",
            systemImageName: "text.book.closed"
        )
        AppShortcut(
            intent: AddWordIntent(),
            phrases: ["Add a word to \(.applicationName)"],
            shortTitle: "Add a word",
            systemImageName: "plus"
        )
    }
}
