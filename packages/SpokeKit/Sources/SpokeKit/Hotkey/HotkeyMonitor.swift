import AppKit
import ApplicationServices

/// Hold-to-talk global hotkey, surfaced as an async stream of events.
///
/// Right Option is the default: reachable by thumb, nothing else uses it,
/// and holding a modifier avoids the "did I toggle it on?" confusion that
/// makes toggle-style dictation feel unreliable.
///
/// Requires Accessibility permission (System Settings › Privacy & Security ›
/// Accessibility). Without it, global monitors silently receive nothing —
/// the #1 "why is my app broken" moment for new macOS developers.
final class HotkeyMonitor {

    /// Press/release events, in order. Consuming this from a single task is
    /// what serializes begin/end handling in `DictationController`.
    let events: AsyncStream<HotkeyEvent>

    private let continuation: AsyncStream<HotkeyEvent>.Continuation
    private var detector = HoldDetector()
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init() {
        (events, continuation) = AsyncStream.makeStream()
    }

    /// Whether macOS has granted us permission to observe global input.
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user, showing the system dialog that deep-links to Settings.
    static func requestAccessibilityPermission() {
        // The literal spelling of `kAXTrustedCheckOptionPrompt`. The real
        // symbol is a C global imported as a mutable `var`, which Swift 6
        // correctly refuses to touch from isolated code.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func start() {
        stop()

        // Global monitor: fires when other apps are focused (the normal case).
        // AppKit delivers these on the main thread.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }

        // Local monitor: fires when our own window is focused. Both are
        // needed, or the hotkey mysteriously dies while Settings is open.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        detector = HoldDetector()
    }

    private func handle(_ event: NSEvent) {
        let transition = detector.transition(
            keyCode: event.keyCode,
            rawModifierFlags: event.modifierFlags.rawValue
        )
        if let transition {
            continuation.yield(transition)
        }
    }
}
