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

    /// Where the pill's bottom-left corner was placed on first layout. Kept
    /// fixed as the transcript grows: re-deriving it from the new width would
    /// slide the pill left on every word, which is far more distracting than
    /// one that simply extends rightward.
    private var anchorOrigin: NSPoint?

    /// Last size actually applied to the panel, so an unchanged layout doesn't
    /// re-set the frame.
    private var appliedSize: NSSize = .zero

    // MARK: - Public API

    func show(mode: OverlayView.Mode) {
        hideTask?.cancel()
        hideTask = nil

        self.mode = mode
        text = ""
        levels = Array(repeating: 0, count: Self.waveformWindow)
        caretAnchor = CaretLocator.caretScreenRect()
        anchorOrigin = nil
        appliedSize = .zero

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
    ///
    /// Redraws without touching the panel's frame. The waveform has a fixed
    /// size, so levels can never change the layout — and re-setting the frame
    /// on every buffer (roughly ten times a second) was sampling `fittingSize`
    /// mid-animation, which both flickered and could shrink the panel around
    /// the waveform, clipping the live transcript out of view.
    func pushLevel(_ level: Float) {
        levels.append(level)
        if levels.count > Self.waveformWindow {
            levels.removeFirst(levels.count - Self.waveformWindow)
        }
        hostingView?.rootView = currentRootView()
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
        resizeIfNeeded()
    }

    // MARK: - Positioning

    /// Applies a new panel size only when the layout genuinely changed.
    private func resizeIfNeeded() {
        guard let panel else { return }

        panel.layoutIfNeeded()
        guard let size = panel.contentView?.fittingSize, size.width > 0, size.height > 0 else {
            return
        }
        guard
            abs(size.width - appliedSize.width) > 0.5 || abs(size.height - appliedSize.height) > 0.5
        else { return }

        appliedSize = size
        panel.setContentSize(size)

        // Placed once, then held: the transcript grows rightward from a fixed
        // corner rather than re-centring under the caret on every word.
        let origin = anchorOrigin ?? preferredOrigin(for: size)
        anchorOrigin = origin
        panel.setFrameOrigin(clampedToScreen(origin, for: size))
    }

    /// Keeps a frame fully on the active screen, whatever the pill grew to.
    private func clampedToScreen(_ origin: NSPoint, for size: NSSize) -> NSPoint {
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let margin: CGFloat = 12
        return NSPoint(
            x: min(max(origin.x, visible.minX + margin), visible.maxX - size.width - margin),
            y: min(max(origin.y, visible.minY + margin), visible.maxY - size.height - margin)
        )
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
