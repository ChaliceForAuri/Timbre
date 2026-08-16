import AppKit
import ApplicationServices
import SwiftUI

/// Owns the floating panel: showing it, hiding it, and putting it in the
/// right place on screen.
///
/// The hard requirement: showing this window must NOT steal keyboard focus.
/// If it does, the app you were typing into loses its cursor and the paste
/// lands in the wrong place — or nowhere. Every setting in `makePanel()`
/// below exists to prevent that.
@MainActor
final class OverlayController {

    private var panel: NSPanel?
    private var hostingView: NSHostingView<OverlayView>?

    private var mode: OverlayView.Mode = .listening
    private var text: String = ""
    private var levels: [Float] = Array(repeating: 0, count: 5)

    // MARK: - Public API

    func show(mode: OverlayView.Mode) {
        self.mode = mode
        self.text = ""
        self.levels = Array(repeating: 0, count: 5)

        let panel = panel ?? makePanel()
        self.panel = panel

        render()
        position(panel)

        panel.alphaValue = 0
        // `orderFrontRegardless` shows the window without activating our app.
        // Using `makeKeyAndOrderFront` here would break focus — the classic bug.
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func update(mode: OverlayView.Mode? = nil, text: String? = nil) {
        if let mode { self.mode = mode }
        if let text { self.text = text }
        render()
    }

    /// Push a new audio level (0...1) into the rolling waveform window.
    func pushLevel(_ level: Float) {
        levels.append(level)
        if levels.count > 5 { levels.removeFirst(levels.count - 5) }
        render()
    }

    func hide(after delay: TimeInterval = 0) {
        guard let panel else { return }

        let dismiss = {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().alphaValue = 0
            } completionHandler: {
                panel.orderOut(nil)
            }
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: dismiss)
        } else {
            dismiss()
        }
    }

    // MARK: - Panel construction

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 60),
            // `.nonactivatingPanel` is the critical one: it tells macOS this
            // window should never make our app active.
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false

        // Sit above normal windows but below system alerts.
        panel.level = .statusBar

        // Transparent chrome so the SwiftUI material provides the whole look.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false          // SwiftUI draws its own, correctly clipped

        // Follow the user across Spaces and appear over full-screen apps —
        // otherwise dictation silently stops working in full-screen Xcode.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Not interactive: clicks should pass straight through to the app
        // underneath. This is a display, not a control.
        panel.ignoresMouseEvents = true

        let view = NSHostingView(rootView: currentRootView())
        view.sizingOptions = [.preferredContentSize]
        panel.contentView = view
        hostingView = view

        return panel
    }

    private func currentRootView() -> OverlayView {
        OverlayView(mode: mode, text: text, levels: levels)
    }

    private func render() {
        hostingView?.rootView = currentRootView()
        if let panel, panel.isVisible { position(panel) }
    }

    // MARK: - Positioning

    private func position(_ panel: NSPanel) {
        panel.layoutIfNeeded()
        let size = panel.contentView?.fittingSize ?? NSSize(width: 260, height: 44)
        panel.setContentSize(size)

        let origin = preferredOrigin(for: size)
        panel.setFrameOrigin(origin)
    }

    /// Prefer just below the text caret; fall back to above the mouse; fall
    /// back again to bottom-centre of the active screen.
    private func preferredOrigin(for size: NSSize) -> NSPoint {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let visible = screen.visibleFrame
        let margin: CGFloat = 12

        var origin: NSPoint

        if let caret = caretScreenRect() {
            // Centre horizontally on the caret, sit just underneath it.
            origin = NSPoint(
                x: caret.midX - size.width / 2,
                y: caret.minY - size.height - margin
            )
            // If there's no room below (caret near the bottom), flip above.
            if origin.y < visible.minY + margin {
                origin.y = caret.maxY + margin
            }
        } else {
            let mouse = NSEvent.mouseLocation
            origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y + 24)
        }

        // Clamp inside the visible screen so it never hangs off an edge.
        origin.x = min(max(origin.x, visible.minX + margin), visible.maxX - size.width - margin)
        origin.y = min(max(origin.y, visible.minY + margin), visible.maxY - size.height - margin)

        return origin
    }

    /// Asks the Accessibility API where the text insertion point is, in
    /// screen coordinates.
    ///
    /// Returns nil often — many apps (terminals, Electron, some web views)
    /// don't expose this. That's expected; the mouse fallback covers it.
    private func caretScreenRect() -> NSRect? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success else { return nil }

        guard CFGetTypeID(focusedRef!) == AXUIElementGetTypeID() else { return nil }
        let focused = unsafeBitCast(focusedRef!, to: AXUIElement.self)

        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeRef
        ) == .success else { return nil }

        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            focused,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeRef!,
            &boundsRef
        ) == .success else { return nil }

        guard CFGetTypeID(boundsRef!) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(boundsRef!, to: AXValue.self)

        var rect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &rect) else { return nil }
        guard rect.width.isFinite, rect.height.isFinite else { return nil }

        return convertFromAccessibility(rect)
    }

    /// Accessibility reports a top-left origin measured from the top of the
    /// primary display. AppKit windows use a bottom-left origin. Getting this
    /// conversion wrong puts your overlay on the wrong monitor, or off-screen
    /// entirely — and it's the single most confusing bug in this file.
    private func convertFromAccessibility(_ rect: CGRect) -> NSRect {
        guard let primary = NSScreen.screens.first else { return rect }
        let primaryHeight = primary.frame.maxY
        return NSRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
