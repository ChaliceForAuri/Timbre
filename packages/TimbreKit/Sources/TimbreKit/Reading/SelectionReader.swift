import AppKit
import ApplicationServices

/// Gets the text the user has selected, in whatever app they're in.
///
/// Two strategies, mirroring `TextInserter` in reverse. The Accessibility
/// API is clean and invisible when it works, but the same apps that hide
/// their caret (Electron, terminals, some web views) hide their selection
/// too. The pasteboard route works essentially everywhere because it's the
/// path a human takes — and the clipboard is saved and restored around it,
/// exactly as insertion does.
enum SelectionReader {

    /// How long to wait for a synthetic ⌘C to land before reading the
    /// pasteboard. The same order as `TextInserter`'s restore delay, and for
    /// the same reason: it's the app on the other side that needs the time.
    private static let copySettleDelay: Duration = .milliseconds(120)

    /// The current selection, or nil if there is none to read.
    static func selectedText() async -> String? {
        if let viaAccessibility = accessibilitySelection() {
            return viaAccessibility
        }
        return await pasteboardSelection()
    }

    // MARK: - Accessibility

    private static func accessibilitySelection() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                systemWide,
                kAXFocusedUIElementAttribute as CFString,
                &focusedRef
            ) == .success,
            let focusedRef,
            CFGetTypeID(focusedRef) == AXUIElementGetTypeID()
        else { return nil }
        let focused = unsafeDowncast(focusedRef, to: AXUIElement.self)

        var selectionRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                focused,
                kAXSelectedTextAttribute as CFString,
                &selectionRef
            ) == .success,
            let selectionRef,
            CFGetTypeID(selectionRef) == CFStringGetTypeID()
        else { return nil }

        let text = unsafeDowncast(selectionRef, to: CFString.self) as String
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }

    // MARK: - Pasteboard

    /// Copies the selection with a synthetic ⌘C and reads it back, leaving
    /// the user's clipboard exactly as it was.
    @MainActor
    private static func pasteboardSelection() async -> String? {
        let pasteboard = NSPasteboard.general
        let saved = PasteboardSnapshot(capturing: pasteboard)
        let changeCountBefore = pasteboard.changeCount

        SyntheticKey.press(.c)
        try? await Task.sleep(for: copySettleDelay)

        // An unchanged change count means nothing was copied — there was no
        // selection. Reading the pasteboard anyway would speak whatever the
        // user last copied, which is a genuinely alarming thing for an app
        // to do unprompted.
        guard pasteboard.changeCount != changeCountBefore else { return nil }

        let copied = pasteboard.string(forType: .string)
        saved.restore(to: pasteboard)

        guard let copied, !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return copied
    }
}
