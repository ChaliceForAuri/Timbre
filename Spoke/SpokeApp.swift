import SwiftUI

/// App entry point.
///
/// Flutter/RN note: `MenuBarExtra` is a scene type — the SwiftUI equivalent of
/// declaring your app has no window, just a menu bar item. There's no
/// `runApp()`; the `@main` attribute plus the `App` protocol is the whole
/// bootstrap. `Settings` gives you the standard Cmd+, window for free.
@main
struct SpokeApp: App {

    @State private var controller = ControllerBox()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(box: controller)
        } label: {
            Image(systemName: controller.iconName)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(box: controller)
        }
    }
}

/// Small wrapper so the app compiles on macOS versions below 26 and shows a
/// clear message instead of failing to launch.
@MainActor
@Observable
final class ControllerBox {

    var unsupportedMessage: String?

    private var _controller: Any?

    @available(macOS 26.0, *)
    var controller: DictationController? {
        _controller as? DictationController
    }

    var iconName: String {
        guard #available(macOS 26.0, *), let controller else { return "exclamationmark.circle" }
        switch controller.state {
        case .settingUp: return "hourglass"
        case .idle:      return "mic"
        case .listening: return "mic.fill"
        case .polishing: return "sparkles"
        case .error:     return "exclamationmark.triangle"
        }
    }

    var statusText: String {
        guard #available(macOS 26.0, *), let controller else {
            return unsupportedMessage ?? "Requires macOS 26 or later."
        }
        switch controller.state {
        case .settingUp:       return "Setting up…"
        case .idle:            return "Ready — hold right ⌥ to dictate"
        case .listening:       return controller.liveText.isEmpty ? "Listening…" : controller.liveText
        case .polishing:       return "Cleaning up…"
        case .error(let msg):  return msg
        }
    }

    init() {
        guard #available(macOS 26.0, *) else {
            unsupportedMessage = "Spoke needs macOS 26 or later for on-device speech."
            return
        }
        let controller = DictationController()
        _controller = controller
        Task { await controller.bootstrap() }
    }
}

struct MenuContent: View {
    @Bindable var box: ControllerBox

    var body: some View {
        Text(box.statusText)

        Divider()

        if #available(macOS 26.0, *), let controller = box.controller {
            Button("Insert Last Again") {
                controller.reinsertLast()
            }
            .disabled(controller.lastInserted.isEmpty)
        }

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

struct SettingsView: View {
    @Bindable var box: ControllerBox
    @State private var newTerm = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spoke")
                .font(.title2.bold())

            Text(box.statusText)
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            Text("Your Vocabulary")
                .font(.headline)

            Text("Names, jargon, and product terms the model should prefer. This never leaves your Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if #available(macOS 26.0, *), let controller = box.controller {
                HStack {
                    TextField("Add a term", text: $newTerm)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        controller.addToVocabulary(newTerm)
                        newTerm = ""
                    }
                    .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                List {
                    ForEach(controller.vocabulary, id: \.self) { term in
                        HStack {
                            Text(term)
                            Spacer()
                            Button {
                                controller.removeFromVocabulary(term)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .frame(minHeight: 160)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 420, height: 460)
    }
}
