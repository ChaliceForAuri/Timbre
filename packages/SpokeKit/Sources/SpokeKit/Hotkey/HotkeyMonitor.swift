import AppKit
import ApplicationServices
import os

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

    /// Lock-wrapped rather than actor-isolated, and the reason is three
    /// identical SIGBUS crash reports (2026-08-19): a MainActor-isolated
    /// handler closure makes Swift compile a runtime executor check into
    /// every monitor callback, and inside AppKit's Carbon-era event dispatch
    /// that check read a stale executor pointer and crashed — Release builds
    /// only. The event path must stay out of the concurrency runtime
    /// entirely: no isolation, no dynamic check, nothing to crash. ADR-0007.
    private nonisolated let detector = OSAllocatedUnfairLock(initialState: HoldDetector())
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

        // Explicitly @Sendable so the closures are nonisolated: a closure
        // that inherits MainActor isolation here gets a dynamic executor
        // check on every event, which is the exact machinery that crashed.
        // They capture only Sendable values — the lock and the continuation —
        // never self.
        let detector = detector
        let continuation = continuation

        // Global monitor: fires when other apps are focused (the normal case).
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) {
            @Sendable event in
            Self.process(event, detector: detector, continuation: continuation)
        }

        // Local monitor: fires when our own window is focused. Both are
        // needed, or the hotkey mysteriously dies while Settings is open.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
            @Sendable event in
            Self.process(event, detector: detector, continuation: continuation)
            return event
        }
    }

    private nonisolated static func process(
        _ event: NSEvent,
        detector: OSAllocatedUnfairLock<HoldDetector>,
        continuation: AsyncStream<HotkeyEvent>.Continuation
    ) {
        let keyCode = event.keyCode
        let rawFlags = event.modifierFlags.rawValue
        let transition = detector.withLock { $0.transition(keyCode: keyCode, rawModifierFlags: rawFlags) }
        if let transition {
            continuation.yield(transition)
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        detector.withLock { $0 = HoldDetector() }
    }

}
