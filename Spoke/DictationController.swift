import AVFoundation
import Foundation
import Observation
import SwiftUI

/// Ties everything together: hotkey → mic → speech model → cleanup → paste.
///
/// Flutter/RN note: `@Observable` is the modern SwiftUI equivalent of a store.
/// Mutating a property here automatically re-renders any view that read it —
/// no `setState`, no selectors, no provider wiring.
@available(macOS 26.0, *)
@MainActor
@Observable
final class DictationController {

    enum State: Equatable {
        case settingUp
        case idle
        case listening
        case polishing
        case error(String)
    }

    private(set) var state: State = .settingUp
    private(set) var liveText: String = ""
    private(set) var lastInserted: String = ""

    /// Words the user has taught the app. Persisted across launches.
    /// This is your differentiator — grow it aggressively.
    var vocabulary: [String] {
        get { UserDefaults.standard.stringArray(forKey: "vocabulary") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "vocabulary") }
    }

    private let audio = AudioCapture()
    private let transcriber = Transcriber()
    private let polisher = TextPolisher()
    private let inserter = TextInserter()
    private let hotkey = HotkeyMonitor()
    private let overlay = OverlayController()

    private var capturedAppName: String?

    // MARK: - Lifecycle

    func bootstrap() async {
        // 1. Accessibility — needed for both the hotkey and the paste.
        if !HotkeyMonitor.hasAccessibilityPermission {
            HotkeyMonitor.requestAccessibilityPermission()
            state = .error("Grant Accessibility access, then restart Spoke.")
            return
        }

        // 2. Microphone.
        let micGranted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
        }
        guard micGranted else {
            state = .error("Microphone access denied.")
            return
        }

        // 3. Speech model — may download on first run.
        guard await Transcriber.isSupported() else {
            state = .error("On-device speech isn't available for \(Locale.current.identifier).")
            return
        }

        do {
            try await transcriber.prepare()
        } catch {
            state = .error("Speech setup failed: \(error.localizedDescription)")
            return
        }

        hotkey.onPress = { [weak self] in
            Task { await self?.beginListening() }
        }
        hotkey.onRelease = { [weak self] in
            Task { await self?.endListening() }
        }
        hotkey.start()

        state = .idle
    }

    // MARK: - Dictation

    private func beginListening() async {
        guard state == .idle else { return }

        // Capture the target app now — by the time we paste, focus is the same,
        // but reading it up front keeps the polish prompt honest.
        capturedAppName = TextInserter.frontmostAppName
        liveText = ""
        state = .listening

        // Show the overlay immediately — before the model is even ready.
        // Perceived latency is what users judge, and an instant pill that
        // says "Listening…" feels faster than a correct one 200ms later.
        overlay.show(mode: .listening)

        do {
            try await transcriber.startDictation { [weak self] text in
                Task { @MainActor in
                    self?.liveText = text
                    self?.overlay.update(text: text)
                }
            }

            try audio.start { [transcriber] buffer in
                Task { await transcriber.feed(buffer) }
            } onLevel: { [weak self] level in
                Task { @MainActor in self?.overlay.pushLevel(level) }
            }
        } catch {
            audio.stop()
            overlay.update(mode: .error(error.localizedDescription))
            overlay.hide(after: 2.5)
            state = .error(error.localizedDescription)
        }
    }

    private func endListening() async {
        guard state == .listening else { return }

        audio.stop()
        state = .polishing
        overlay.update(mode: .polishing)

        do {
            let raw = try await transcriber.finishDictation()
            guard !raw.isEmpty else {
                overlay.hide()
                state = .idle
                liveText = ""
                return
            }

            let cleaned = await polisher.polish(
                raw,
                appContext: capturedAppName,
                vocabulary: vocabulary
            )

            // Hide BEFORE pasting. If the overlay is still on screen when the
            // synthetic Cmd+V fires, the user sees the pill flicker over their
            // own text — it reads as a glitch even though nothing went wrong.
            overlay.hide()
            inserter.insert(cleaned)

            lastInserted = cleaned
            liveText = ""
            state = .idle
        } catch {
            overlay.update(mode: .error(error.localizedDescription))
            overlay.hide(after: 2.5)
            state = .error(error.localizedDescription)
        }
    }

    /// Re-inserts the last result — handy when focus was wrong.
    func reinsertLast() {
        guard !lastInserted.isEmpty else { return }
        inserter.insert(lastInserted)
    }

    func addToVocabulary(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !vocabulary.contains(trimmed) else { return }
        vocabulary.append(trimmed)
    }

    func removeFromVocabulary(_ term: String) {
        vocabulary.removeAll { $0 == term }
    }
}
