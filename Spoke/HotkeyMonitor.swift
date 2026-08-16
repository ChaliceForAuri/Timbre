import AppKit
import Foundation

/// Hold-to-talk global hotkey.
///
/// Default is right-Option: it's reachable by thumb, nothing else uses it,
/// and holding a modifier avoids the "did I toggle it on?" confusion that
/// makes toggle-style dictation feel unreliable.
///
/// Requires Accessibility permission (System Settings › Privacy & Security ›
/// Accessibility). Without it, global monitors silently receive nothing —
/// which is the #1 "why is my app broken" moment for new macOS devs.
@MainActor
final class HotkeyMonitor {

    /// Right Option. (Left Option is 58, right Command is 54, Fn is 63.)
    private static let rightOptionKeyCode: UInt16 = 61

    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isHeld = false

    /// Whether macOS has granted us permission to observe global input.
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user, showing the system dialog that deep-links to Settings.
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func start() {
        stop()

        // Global monitor: fires when other apps are focused (the normal case).
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }

        // Local monitor: fires when our own window is focused. You need both,
        // or the hotkey mysteriously dies while the Settings window is open.
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
        isHeld = false
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == Self.rightOptionKeyCode else { return }

        // `.flagsChanged` tells us a modifier moved but not which direction,
        // so we read the current flag state to decide press vs release.
        let optionDown = event.modifierFlags.contains(.option)

        if optionDown && !isHeld {
            isHeld = true
            onPress()
        } else if !optionDown && isHeld {
            isHeld = false
            onRelease()
        }
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }
}
