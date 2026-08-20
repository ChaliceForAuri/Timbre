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

    /// Whether dictations are being saved locally as tuning fixtures.
    /// Off unless the user turns it on — see GDR-0004.
    public var isCapturingDictations: Bool {
        get { dictationLog.isCapturing }
        set { dictationLog.isCapturing = newValue }
    }

    /// Where captured dictations are written, for the settings screen.
    public var captureFileURL: URL { dictationLog.fileURL }

    /// How many dictations have been captured so far.
    public func capturedDictationCount() -> Int { dictationLog.recordCount() }

    /// Deletes every captured dictation.
    public func deleteCapturedDictations() { dictationLog.deleteAll() }

    private let audio = AudioCapture()
    private let transcriber = Transcriber()
    private let polisher = TextPolisher()
    private let inserter = TextInserter()
    private let hotkey = HotkeyMonitor()
    private let overlay = OverlayController()
    private let vocabularyStore = VocabularyStore()
    private let dictationLog = DictationLog()

    private var capturedAppName: String?
    private var pressInstant: ContinuousClock.Instant?
    private var microphoneStart: Duration?
    private var firstAudio: Duration?
    private var hotkeyLoop: Task<Void, Never>?
    private var accessibilityWatch: Task<Void, Never>?
    private var displayTasks: [Task<Void, Never>] = []

    public init() {}

    // MARK: - Lifecycle

    public func bootstrap() async {
        // 1. Permissions. Microphone first and unconditionally: it is the one
        //    macOS grants in place, and gating it behind Accessibility meant
        //    the prompt never fired — leaving Spoke absent from Privacy &
        //    Security › Microphone entirely, since an app is listed there only
        //    once it has asked. StartupGate reports everything missing at once.
        let microphoneGranted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
        }

        let accessibilityGranted = HotkeyMonitor.hasAccessibilityPermission
        if !accessibilityGranted {
            HotkeyMonitor.requestAccessibilityPermission()
        }

        let permissions = StartupGate.Permissions(
            microphone: microphoneGranted,
            accessibility: accessibilityGranted
        )
        if let message = StartupGate.blockingMessage(for: permissions) {
            status = .error(message)
            if microphoneGranted, !accessibilityGranted {
                watchForAccessibilityGrant()
            }
            return
        }

        // 2. Speech model — may download assets on first run.
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

        // 3. Page the polisher's model weights in so the first dictation
        //    isn't the slow one.
        polisher.prewarm()

        // 4. The hotkey loop. A single consumer of the event stream is what
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

    /// Retries startup once the user grants Accessibility, so they don't have
    /// to quit and relaunch.
    ///
    /// Polls rather than observing: `AXIsProcessTrusted()` is a cheap local
    /// check, and the notification that would replace this is undocumented.
    /// If the trusted state turns out to be cached for the lifetime of the
    /// process, this simply never fires and the user relaunches as before —
    /// it cannot make things worse.
    private func watchForAccessibilityGrant() {
        accessibilityWatch?.cancel()
        accessibilityWatch = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard HotkeyMonitor.hasAccessibilityPermission else { continue }
                guard let self else { return }
                await self.bootstrap()
                return
            }
        }
    }

    // MARK: - Dictation

    private func beginListening() async {
        // Starting from .error is deliberate: one transient failure must not
        // require a relaunch to make the hotkey work again.
        switch status {
        case .idle, .error: break
        default: return
        }

        // No input device — headphones off, no mic on a Mac Studio — must
        // fail here, loudly, not four steps later. Without this, the engine
        // starts cleanly, delivers nothing, and the finish path used to hang.
        guard AVCaptureDevice.default(for: .audio) != nil else {
            overlay.show(mode: .error("No microphone connected."))
            overlay.hide(after: .seconds(2.5))
            return
        }

        // Capture the target app now — by the time we paste, focus is the
        // same, but reading it up front keeps the polish prompt honest.
        capturedAppName = TextInserter.frontmostAppName
        liveText = ""
        status = .listening

        let clock = ContinuousClock()
        let pressed = clock.now
        pressInstant = pressed
        microphoneStart = nil
        firstAudio = nil

        do {
            guard let format = await transcriber.analyzerFormat else {
                throw Transcriber.TranscriberError.notPrepared
            }

            // The microphone opens FIRST — before the overlay, whose caret
            // lookup is a synchronous IPC round-trip into another process.
            // On a Bluetooth mic the headset takes hundreds of milliseconds
            // to wake; every millisecond of our own work belongs inside that
            // window, not in front of it. Issue #4.
            let streams = try audio.start(convertingTo: format)
            microphoneStart = clock.now - pressed

            // The pill must not say "Listening" yet: no audio is flowing,
            // and inviting speech into dead air is the clipped-first-words
            // bug. The level task below flips it the moment sound arrives.
            overlay.show(mode: .warming)

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
                    var heardAudio = false
                    for await level in streams.levels {
                        guard let self else { return }
                        // Strictly non-zero: a waking Bluetooth mic delivers
                        // buffers of exact digital zeros immediately, so
                        // "a buffer arrived" is not "the mic is alive". A
                        // live capture always carries a noise floor; only a
                        // dead route is perfectly silent. Flipping on the
                        // first buffer made the pill say "Listening" into
                        // dead air — the same lie, one level down.
                        if !heardAudio, level > 0 {
                            heardAudio = true
                            self.firstAudio = clock.now - pressed
                            self.overlay.update(mode: .listening)
                        }
                        self.overlay.pushLevel(level)
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

        // Read before stop() — stopping discards the tap processor that
        // knows whether any buffers ever arrived.
        let heardAudio = audio.hasDeliveredAudio

        // Finishing the audio streams first lets the analyzer flush through
        // end of input; the transcriber then reports the full utterance.
        audio.stop()

        // A session that heard nothing (device vanished mid-hold, Bluetooth
        // mic never woke) has nothing to finalize — and finalizing an
        // analyzer that got no audio hangs. Tear it down instead.
        guard heardAudio else {
            _ = try? await transcriber.finishDictation()
            cancelDisplayTasks()
            overlay.update(mode: .error("The microphone didn't deliver any audio."))
            overlay.hide(after: .seconds(2.5))
            liveText = ""
            status = .idle
            return
        }

        status = .polishing
        overlay.update(mode: .polishing)

        do {
            let clock = ContinuousClock()
            let released = clock.now
            let raw = try await transcriber.finishDictation()
            let transcriptDuration = clock.now - released
            cancelDisplayTasks()

            guard !raw.isEmpty else {
                overlay.hide()
                becomeIdle()
                return
            }

            let polishStarted = clock.now
            let cleaned = await polisher.polish(
                raw,
                appContext: capturedAppName,
                vocabulary: vocabularyStore.terms
            )
            let polishDuration = clock.now - polishStarted

            // Hide BEFORE pasting. If the overlay is still on screen when the
            // synthetic ⌘V fires, the pill flickers over the user's own text —
            // it reads as a glitch even though nothing went wrong.
            overlay.hide()
            inserter.insert(cleaned)

            // After the paste, never before: capturing a fixture must not sit
            // between the user releasing the key and their text appearing.
            dictationLog.append(
                DictationRecord(
                    id: UUID().uuidString,
                    date: Date(),
                    appContext: capturedAppName,
                    transcript: raw,
                    polished: cleaned,
                    timings: DictationTimings(
                        microphoneStartMs: (microphoneStart ?? .zero).wholeMilliseconds,
                        firstAudioMs: (firstAudio ?? .zero).wholeMilliseconds,
                        transcriptMs: transcriptDuration.wholeMilliseconds,
                        polishMs: polishDuration.wholeMilliseconds
                    )
                )
            )

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
