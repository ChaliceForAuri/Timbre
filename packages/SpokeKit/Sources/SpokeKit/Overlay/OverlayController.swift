import AppKit
import SwiftUI

/// Owns the floating pill: showing it, hiding it, and placing it on screen.
///
/// The hard requirement: showing this window must NOT steal keyboard focus.
/// If it does, the app the user was typing into loses its cursor and the
/// paste lands in the wrong place — or nowhere. Every setting in
/// `makePanel()` exists to prevent that.
final class OverlayController {

    /// How many recent audio levels the waveform shows.
    private static let waveformWindow = 5

    private var panel: NSPanel?
    private var hostingView: NSHostingView<OverlayView>?
    private var hideTask: Task<Void, Never>?

    private var mode: OverlayView.Mode = .listening
    private var text = ""
    private var levels: [Float] = Array(repeating: 0, count: waveformWindow)

    /// The caret position, resolved once per dictation at `show()`. The
    /// lookup is a synchronous IPC round-trip into the focused app, so it
    /// must never happen per text update or per audio level.
    private var caretAnchor: NSRect?

    // MARK: - Public API

    func show(mode: OverlayView.Mode) {
        hideTask?.cancel()
        hideTask = nil

        self.mode = mode
        text = ""
        levels = Array(repeating: 0, count: Self.waveformWindow)
        caretAnchor = CaretLocator.caretScreenRect()

        let panel = panel ?? makePanel()
        self.panel = panel

        render()

        panel.alphaValue = 0
        // `orderFrontRegardless` shows the window without activating our app.
        // `makeKeyAndOrderFront` here would break focus — the classic bug.
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
        if levels.count > Self.waveformWindow {
            levels.removeFirst(levels.count - Self.waveformWindow)
        }
        render()
    }

    func hide(after delay: Duration = .zero) {
        guard let panel else { return }

        hideTask?.cancel()
        guard delay > .zero else {
            dismiss(panel)
            return
        }

        // Tracked so a new show() cancels a pending hide — otherwise an
        // error's delayed dismissal would swallow the next dictation's pill.
        hideTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            dismiss(panel)
        }
    }

    private func dismiss(_ panel: NSPanel) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    // MARK: - Panel construction

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 60),
            // `.nonactivatingPanel` is the critical one: this window must
            // never make our app active.
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
        panel.hasShadow = false  // SwiftUI draws its own, correctly clipped

        // Follow the user across Spaces and appear over full-screen apps —
        // otherwise dictation silently stops working in full-screen Xcode.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Not interactive: clicks pass straight through to the app
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
        if let panel, panel.isVisible || panel.alphaValue == 0 {
            position(panel)
        }
    }

    // MARK: - Positioning

    private func position(_ panel: NSPanel) {
        panel.layoutIfNeeded()
        let size = panel.contentView?.fittingSize ?? NSSize(width: 260, height: 44)
        panel.setContentSize(size)
        panel.setFrameOrigin(preferredOrigin(for: size))
    }

    /// Prefer just below the caret; fall back to above the mouse; clamp to
    /// the visible screen either way.
    private func preferredOrigin(for size: NSSize) -> NSPoint {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let margin: CGFloat = 12

        var origin: NSPoint

        if let caret = caretAnchor {
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
}
