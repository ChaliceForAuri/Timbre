import SpokeKit
import SwiftUI

/// App entry point: a menu bar item and the standard ⌘, settings window.
/// Everything real lives in SpokeKit; this target is scenes and glue only
/// (ADR-0002).
@main
struct SpokeApp: App {

    @State private var controller = DictationController()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(controller: controller)
        } label: {
            Image(systemName: iconName)
                .task { await controller.bootstrap() }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(controller: controller)
        }
    }

    private var iconName: String {
        switch controller.status {
        case .settingUp: "hourglass"
        case .idle: "mic"
        case .listening: "mic.fill"
        case .polishing: "sparkles"
        case .error: "exclamationmark.triangle"
        }
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
