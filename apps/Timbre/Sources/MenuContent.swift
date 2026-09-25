import SwiftUI
import TimbreKit

struct MenuContent: View {
    let controller: DictationController
    let updater: SoftwareUpdater

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(controller.statusText)

        // Found by the daily check, if the user turned it on. A menu item,
        // never a pop-up: nothing appears unless the user comes looking.
        if case .available(let release) = updater.state {
            Button("Install Timbre \(release.version)…") {
                UpdatePrompt.offer(release, updater: updater)
            }
        }

        Divider()

        // The whole interface is three keys. Listed here because there is
        // nowhere else a menu-bar app can put its instructions.
        Menu("Shortcuts") {
            Text("Hold right ⌥ — dictate")
            Text("Tap left ⌥ — read the selection aloud")
            Text("Hold right ⌘ on a selection — fix · explain · shorten")
        }

        Button("Insert Last Again") {
            controller.reinsertLast()
        }
        .disabled(controller.lastInserted.isEmpty)

        // Not SettingsLink: it opens the window without activating the app,
        // and an LSUIElement app is never active — so the window appeared
        // behind everything, or seemingly not at all. Activate first, then
        // open; stealing focus is correct here, the user asked for a window.
        Button("Check for Updates…") {
            UpdatePrompt.checkAndReport(updater)
        }
        .disabled(updater.state == .checking)

        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }

        Divider()

        Button("Quit Timbre") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
