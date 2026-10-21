import SwiftUI
import TimbreKit

/// App entry point: a menu bar item and the standard ⌘, settings window.
/// Everything real lives in TimbreKit; this target is scenes and glue only
/// (ADR-0002).
@main
struct TimbreApp: App {

    @State private var controller = DictationController()
    @State private var updater = SoftwareUpdater()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuContent(controller: controller, updater: updater)
        } label: {
            Image(nsImage: MenuBarIcon.image(for: controller.status))
                .task {
                    updater.start()
                    controller.wordOfTheDay.onOpenCard = { WordCardWindow.open(openWindow) }
                    await controller.bootstrap()
                }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(controller: controller, updater: updater)
        }

        Window("Word of the day", id: WordCardWindow.id) {
            WordCardView(wordOfTheDay: controller.wordOfTheDay)
                .onAppear { controller.wordOfTheDay.refresh() }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Window("Practice", id: PracticeWindow.id) {
            PracticeView(session: controller.practice)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

extension DictationController {
    /// One line of user-facing state, shared by the menu and Settings.
    var statusText: String {
        switch status {
        case .settingUp: "Setting up…"
        case .idle: "Ready — hold right ⌥ to dictate"
        case .listening: liveText.isEmpty ? "Listening…" : liveText
        case .polishing: "Cleaning up…"
        case .error(let message): message
        }
    }
}
