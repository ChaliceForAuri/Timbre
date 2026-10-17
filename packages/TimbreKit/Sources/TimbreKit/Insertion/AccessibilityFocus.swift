import AppKit
import ApplicationServices

/// The element that has keyboard focus, through the Accessibility API.
///
/// Native apps answer the system-wide question. Chromium-based apps —
/// Electron, Chrome, the Claude app, VS Code, Slack — keep their
/// accessibility tree switched off until an assistive client asks for it,
/// and answer the system-wide question with nothing. Asking the frontmost
/// application directly, after setting Chromium's documented
/// `AXManualAccessibility` switch on it, turns the tree on for this and
/// every later hold. One more IPC round-trip, only on the path that would
/// otherwise have found nothing.
nonisolated enum AccessibilityFocus {

    static func focusedElement() -> (element: AXUIElement, note: String?)? {
        if let element = focused(of: AXUIElementCreateSystemWide()) {
            return (element, nil)
        }
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        if let element = focused(of: appElement) {
            return (element, "via app element")
        }
        return nil
    }

    private static func focused(of parent: AXUIElement) -> AXUIElement? {
        var ref: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(parent, kAXFocusedUIElementAttribute as CFString, &ref) == .success,
            let ref,
            CFGetTypeID(ref) == AXUIElementGetTypeID()
        else { return nil }
        return unsafeDowncast(ref, to: AXUIElement.self)
    }
}
