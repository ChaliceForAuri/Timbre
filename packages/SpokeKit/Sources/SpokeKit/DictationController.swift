import AVFoundation
import Foundation
import Observation

/// Ties everything together: hotkey → mic → speech model → cleanup → paste.
///
/// This is the package's public surface. The app shell reads `status`,
/// `liveText`, and the vocabulary API; everything else is internal to
/// SpokeKit.
@Observable
public final class DictationController {

    public nonisolated enum Status: Equatable, Sendable {
        case settingUp
        case idle
        case listening
        case polishing
        case error(String)
    }

    public private(set) var status: Status = .settingUp
    public private(set) var liveText = ""
    public private(set) var lastInserted = ""

    /// Words the user has taught the app. Persisted across launches.
    public var vocabulary: [String] {
        vocabularyStore.terms
    }

    private let audio = AudioCapture()
    private let transcriber = Transcriber()
    private let polisher = TextPolisher()
    private let inserter = TextInserter()
    private let hotkey = HotkeyMonitor()
    private let overlay = OverlayController()
    private let vocabularyStore = VocabularyStore()

    private var capturedAppName: String?
    private var hotkeyLoop: Task<Void, Never>?
    private var displayTasks: [Task<Void, Never>] = []

    public init() {}

    // MARK: - Lifecycle

    public func bootstrap() async {
        // 1. Accessibility — needed for both the hotkey and the paste.
        //    Only read at launch; the app must be relaunched after granting.
        if !HotkeyMonitor.hasAccessibilityPermission {
            HotkeyMonitor.requestAccessibilityPermission()
            status = .error("Grant Accessibility access, then restart Spoke.")
            return
        }

        // 2. Microphone.
        let microphoneGranted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
        }
        guard microphoneGranted else {
            status = .error("Microphone access denied.")
            return
        }

        // 3. Speech model — may download assets on first run.
        guard await Transcriber.isSupported() else {
            status = .error("On-device speech isn't available for \(Locale.current.identifier).")
            return
        }

        do {
            try await transcriber.prepare()
        } catch {
            status = .error("Speech setup failed: \(error.localizedDescription)")
            return
        }

        // 4. Page the polisher's model weights in so the first dictation
        //    isn't the slow one.
        polisher.prewarm()

        // 5. The hotkey loop. A single consumer of the event stream is what
        //    serializes press/release handling: a release that arrives while
        //    beginListening() is still setting up waits its turn instead of
        //    racing it — the failure mode where a quick tap left the app
        //    stuck listening forever.
        hotkey.start()
        hotkeyLoop = Task { [weak self] in
            guard let events = self?.hotkey.events else { return }
            for await event in events {
                guard let self else { return }
                switch event {
                case .pressed: await self.beginListening()
                case .released: await self.endListening()
                }
            }
        }

        status = .idle
    }

    // MARK: - Dictation

    private func beginListening() async {
        // Starting from .error is deliberate: one transient failure must not
        // require a relaunch to make the hotkey work again.
        switch status {
        case .idle, .error: break
        default: return
        }

        // Capture the target app now — by the time we paste, focus is the
        // same, but reading it up front keeps the polish prompt honest.
        capturedAppName = TextInserter.frontmostAppName
        liveText = ""
        status = .listening

        // Show the overlay immediately — before the model is even ready.
        // Perceived latency is what users judge, and an instant pill that
        // says "Listening…" feels faster than a correct one 200 ms later.
        overlay.show(mode: .listening)

        do {
            guard let format = await transcriber.analyzerFormat else {
                throw Transcriber.TranscriberError.notPrepared
            }

            let streams = try audio.start(convertingTo: format)
            let snapshots = try await transcriber.startDictation(consuming: streams.input)

            displayTasks = [
                Task { [weak self] in
                    for await text in snapshots {
                        guard let self else { return }
                        self.liveText = text
                        self.overlay.update(text: text)
                    }
                },
                Task { [weak self] in
                    for await level in streams.levels {
                        self?.overlay.pushLevel(level)
                    }
                },
            ]
        } catch {
            audio.stop()
            showFailure(error)
        }
    }

    private func endListening() async {
        guard status == .listening else { return }

        // Finishing the audio streams first lets the analyzer flush through
        // end of input; the transcriber then reports the full utterance.
        audio.stop()
        status = .polishing
        overlay.update(mode: .polishing)

        do {
            let raw = try await transcriber.finishDictation()
            cancelDisplayTasks()

            guard !raw.isEmpty else {
                overlay.hide()
                becomeIdle()
                return
            }

            let cleaned = await polisher.polish(
                raw,
                appContext: capturedAppName,
                vocabulary: vocabularyStore.terms
            )

            // Hide BEFORE pasting. If the overlay is still on screen when the
            // synthetic ⌘V fires, the pill flickers over the user's own text —
            // it reads as a glitch even though nothing went wrong.
            overlay.hide()
            inserter.insert(cleaned)

            lastInserted = cleaned
            becomeIdle()
        } catch {
            cancelDisplayTasks()
            showFailure(error)
        }
    }

    /// Re-inserts the last result — handy when focus was wrong.
    public func reinsertLast() {
        guard !lastInserted.isEmpty else { return }
        inserter.insert(lastInserted)
    }

    // MARK: - Vocabulary

    public func addToVocabulary(_ term: String) {
        vocabularyStore.add(term)
    }

    public func removeFromVocabulary(_ term: String) {
        vocabularyStore.remove(term)
    }

    // MARK: - Helpers

    private func becomeIdle() {
        liveText = ""
        status = .idle
    }

    private func showFailure(_ error: Error) {
        overlay.update(mode: .error(error.localizedDescription))
        overlay.hide(after: .seconds(2.5))
        liveText = ""
        status = .error(error.localizedDescription)
    }

    private func cancelDisplayTasks() {
        for task in displayTasks {
            task.cancel()
        }
        displayTasks = []
    }
}
