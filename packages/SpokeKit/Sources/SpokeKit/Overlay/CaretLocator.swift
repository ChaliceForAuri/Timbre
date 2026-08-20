import AppKit
import ApplicationServices
import os

/// Finds the text insertion point on screen, in AppKit coordinates.
enum CaretLocator {

    private static let logger = Logger(subsystem: "dev.hugopretorius.Spoke", category: "overlay")

    /// Asks the Accessibility API where the focused element's caret is.
    ///
    /// Returns nil often — terminals, Electron apps, and some web views
    /// don't expose this. That's expected; callers fall back to the mouse.
    ///
    /// This is a synchronous IPC round-trip into another process. Call it
    /// once per dictation (at overlay show), never per frame.
    static func caretScreenRect() -> NSRect? {
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
        else {
            logger.log("caret: no focused element via AX")
            return nil
        }
        let focused = unsafeDowncast(focusedRef, to: AXUIElement.self)

        var rangeRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                focused,
                kAXSelectedTextRangeAttribute as CFString,
                &rangeRef
            ) == .success,
            let rangeRef
        else {
            logger.log("caret: focused element has no selected-text range")
            return nil
        }

        var boundsRef: CFTypeRef?
        guard
            AXUIElementCopyParameterizedAttributeValue(
                focused,
                kAXBoundsForRangeParameterizedAttribute as CFString,
                rangeRef,
                &boundsRef
            ) == .success,
            let boundsRef,
            CFGetTypeID(boundsRef) == AXValueGetTypeID()
        else {
            logger.log("caret: element rejected bounds-for-range (typical for Electron/web views)")
            return nil
        }
        let axValue = unsafeDowncast(boundsRef, to: AXValue.self)

        var rect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &rect) else { return nil }
        guard rect.width.isFinite, rect.height.isFinite else { return nil }

        guard let primary = NSScreen.screens.first else { return nil }
        let converted = convertFromAccessibility(rect, primaryScreenHeight: primary.frame.maxY)
        logger.log(
            "caret raw AX \(String(describing: rect), privacy: .public) → converted \(String(describing: converted), privacy: .public)"
        )
        return converted
    }

    /// Accessibility reports a top-left origin measured from the top of the
    /// primary display; AppKit windows use a bottom-left origin. Getting this
    /// conversion wrong puts the overlay on the wrong monitor, or off-screen
    /// entirely — the single most confusing bug in this layer.
    nonisolated static func convertFromAccessibility(
        _ rect: CGRect,
        primaryScreenHeight: CGFloat
    ) -> NSRect {
        NSRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
