import SpokeKit
import SwiftUI

struct MenuContent: View {
    let controller: DictationController

    var body: some View {
        Text(controller.statusText)

        Divider()

        Button("Insert Last Again") {
            controller.reinsertLast()
        }
        .disabled(controller.lastInserted.isEmpty)

        SettingsLink {
            Text("Settings…")
        }

        Divider()

        Button("Quit Spoke") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
