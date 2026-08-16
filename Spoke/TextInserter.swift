import AppKit
import Foundation

/// Puts text into whatever field the user is focused on, in any app.
///
/// This is the unglamorous part where competing dictation apps quietly break.
/// Two strategies exist:
///
///   1. Accessibility API (`AXUIElement`) — set the focused element's value
///      directly. Clean, but many apps (Electron, terminals, some web views)
///      either don't expose a settable value or mangle the result.
///   2. Pasteboard + synthetic Cmd+V — works essentially everywhere, because
///      you're using the same path a human uses.
///
/// We use (2) with the clipboard restored afterwards, which is what the
/// shipping apps in this category converged on. Correctness beats elegance.
@MainActor
final class TextInserter {

    /// Name of the app that was frontmost — feed this to the polisher so it
    /// can match tone to context (Slack vs. Mail vs. Xcode).
    static var frontmostAppName: String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }

    func insert(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general

        // Save whatever the user had on their clipboard so we can put it back.
        // Skipping this is a small betrayal users notice immediately.
        let saved = pasteboard.pasteboardItems?.compactMap { item -> [NSPasteboard.PasteboardType: Data] in
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { contents[type] = data }
            }
            return contents
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        pressCommandV()

        // Restore after the paste has been consumed. The delay is a heuristic:
        // too short and you paste the old clipboard, too long and the user
        // notices. ~150ms is the sweet spot in practice.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            pasteboard.clearContents()
            guard let saved, !saved.isEmpty else { return }
            for contents in saved {
                let item = NSPasteboardItem()
                for (type, data) in contents {
                    item.setData(data, forType: type)
                }
                pasteboard.writeObjects([item])
            }
        }
    }

    /// Synthesizes a Cmd+V keystroke at the system level.
    private func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Don't let our synthetic keystroke be seen by our own event taps.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let vKeyCode: CGKeyCode = 9  // 'v'

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
