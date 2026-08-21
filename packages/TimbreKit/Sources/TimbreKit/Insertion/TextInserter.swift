import AppKit

/// Puts text into whatever field the user is focused on, in any app, via the
/// pasteboard and a synthetic ⌘V. See ADR-0003 for why this mechanism beat
/// the Accessibility API: it's the same path a human takes, so it works
/// essentially everywhere.
final class TextInserter {

    /// How long the target app gets to consume the paste before we restore
    /// the user's pasteboard. Too short pastes the old clipboard; too long
    /// is user-visible. ~150 ms is the sweet spot in practice.
    private static let pasteboardRestoreDelay: Duration = .milliseconds(150)

    /// Name of the app that was frontmost — fed to the polisher so it can
    /// match tone to context (Slack vs. Mail vs. Xcode).
    static var frontmostAppName: String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }

    func insert(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general

        // Without Accessibility permission the synthetic ⌘V goes nowhere.
        // Leave the text on the pasteboard so the user can paste manually —
        // never lose an utterance, even in the failure path.
        guard HotkeyMonitor.hasAccessibilityPermission else {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return
        }

        let snapshot = PasteboardSnapshot(capturing: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        SyntheticKey.press(.v)

        Task {
            try? await Task.sleep(for: Self.pasteboardRestoreDelay)
            snapshot.restore(to: pasteboard)
        }
    }

}
