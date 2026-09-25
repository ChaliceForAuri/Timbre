import AVFoundation
import Foundation
import Observation

/// Ties everything together: hotkey → mic → speech model → cleanup → paste,
/// plus the two gestures that work on a selection — read aloud and command mode.
///
/// This is the package's public surface. The app shell reads `status`,
/// `liveText`, and the vocabulary API; everything else is internal to
/// TimbreKit.
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

    /// Phrases the user has corrected: what Timbre heard, what they meant.
    /// Applied to every transcript before the model (GDR-0011).
    public var corrections: [Correction] {
        vocabularyStore.corrections
    }

    /// Terms the user has defined. They answer "explain" before the model
    /// does (GDR-0012).
    public var acronyms: [Acronym] {
        vocabularyStore.acronyms
    }

    /// The voice read-aloud will use, and whether macOS has a better one
    /// available for download. Nil when no voice is installed at all.
    public var readingVoiceName: String? { VoiceCatalog.preferred()?.name }

    /// True when the best installed voice is a compact one — the 2005-era
    /// default. Enhanced and Premium voices are free downloads and sound
    /// completely different, so this is worth surfacing rather than leaving
    /// the user to conclude the feature is bad.
    public var readingVoiceIsCompact: Bool {
        guard let best = VoiceCatalog.preferred() else { return false }
        return !best.isHighQuality
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
    private let speech = SpeechReader()
    private let transformer = TextTransformer()

    private var capturedAppName: String?
    private var pressInstant: ContinuousClock.Instant?
    private var readHoldTask: Task<Void, Never>?
    private var readHoldFired = false

    /// Which hold owns the microphone. Dictation and command mode share the
    /// capture path and the `.listening` status, so the release of one key
    /// must never be allowed to finish the other's session.
    private enum Gesture { case dictation, command }
    private var gesture: Gesture?
    private var commandArmTask: Task<Void, Never>?
    private var commandSelection: String?
    private var commandIsCapturing = false
    private var commandHold = CommandHold()
    private var lastExplanationPush: ContinuousClock.Instant?
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
        //    the prompt never fired — leaving Timbre absent from Privacy &
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
        //    isn't the slow one, and load the read-aloud voice for the same
        //    reason.
        polisher.prewarm()
        speech.prewarm()

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
                case .pressed:
                    self.cancelPendingCommand()
                    await self.beginListening()
                case .released: await self.endListening()
                case .readKeyDown: self.readKeyWentDown()
                case .readKeyUp: await self.readKeyWentUp()
                case .commandKeyDown: self.commandKeyWentDown()
                case .commandKeyUp: await self.commandKeyWentUp()
                case .commandInterrupted: await self.commandWasInterrupted()
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
        guard gesture == nil else { return }
        switch status {
        case .idle, .error: break
        default: return
        }

        // Talking beats listening: starting a dictation silences any
        // read-aloud in progress rather than layering two voices.
        speech.stop()

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

        gesture = .dictation
        do {
            try await startCapture(
                listeningMode: .listening,
                vocabulary: vocabularyStore.terms,
                pressed: pressed
            )
        } catch {
            audio.stop()
            showFailure(error)
        }
    }

    /// Opens the microphone, starts a speech session and wires the pill to
    /// both: the part of a hold that dictation and command mode share.
    ///
    /// `onTranscript` sees every live transcript as it arrives, after the
    /// pill does; command mode uses it to act on the word, not the release.
    private func startCapture(
        listeningMode: OverlayView.Mode,
        vocabulary: [String],
        pressed: ContinuousClock.Instant,
        onTranscript: ((String) -> Void)? = nil
    ) async throws {
        let clock = ContinuousClock()
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

        let snapshots = try await transcriber.startDictation(
            consuming: streams.input,
            vocabulary: vocabulary
        )

        displayTasks = [
            Task { [weak self] in
                for await text in snapshots {
                    guard let self else { return }
                    self.liveText = text
                    self.overlay.update(text: text)
                    onTranscript?(text)
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
                        self.overlay.update(mode: listeningMode)
                    }
                    self.overlay.pushLevel(level)
                }
            },
        ]
    }

    private func endListening() async {
        guard status == .listening, gesture == .dictation else { return }

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
            becomeIdle()
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
                vocabulary: vocabularyStore.terms,
                corrections: vocabularyStore.corrections
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

    // MARK: - Command mode

    /// How long right ⌘ must be held, uninterrupted, before it means command
    /// mode. Right ⌘ is a working shortcut key — ⌘P, ⌘-click — so a hold only
    /// counts once it has outlasted an ordinary shortcut, and the pill
    /// appearing is the cue that releasing now will do something. GDR-0012.
    private static let commandArmDelay: Duration = .milliseconds(350)

    /// Right ⌘ went down. Nothing visible happens yet: the hold has to
    /// survive the arm delay with no other key, click or modifier, any of
    /// which means it was a shortcut (`commandWasInterrupted`).
    private func commandKeyWentDown() {
        guard gesture == nil else { return }
        switch status {
        case .idle, .error: break
        default: return
        }

        hotkey.beginInterruptionWatch()
        commandArmTask?.cancel()
        commandArmTask = Task { [weak self] in
            try? await Task.sleep(for: Self.commandArmDelay)
            guard let self, !Task.isCancelled else { return }
            // Claimed synchronously, before any suspension, so a release
            // landing during setup knows the session has begun and waits for
            // it rather than cancelling half of one.
            self.gesture = .command
            await self.beginCommand()
        }
    }

    private func commandKeyWentUp() async {
        hotkey.endInterruptionWatch()
        await settleCommandArming()
        await endCommand()
    }

    /// A key, a click or another modifier arrived mid-hold: the user was
    /// typing a shortcut. Put everything back, silently — unless a command
    /// already fired, in which case their other keys are their own business.
    private func commandWasInterrupted() async {
        hotkey.endInterruptionWatch()
        await settleCommandArming()
        guard gesture == .command, commandHold.acceptsInterruption else { return }
        await abandonCommand()
    }

    /// Cancels a hold that has not armed, or waits out the setup of one that
    /// has. Cancelling an armed session mid-setup would surface as a thrown
    /// cancellation from the speech stack — an error pill for a normal release.
    private func settleCommandArming() async {
        let arming = commandArmTask
        commandArmTask = nil
        if gesture != .command { arming?.cancel() }
        await arming?.value
    }

    /// Right ⌥ went down while a right-⌘ hold was still waiting to arm:
    /// dictation wins, the pending command is forgotten.
    private func cancelPendingCommand() {
        guard gesture != .command else { return }
        hotkey.endInterruptionWatch()
        commandArmTask?.cancel()
        commandArmTask = nil
    }

    private func beginCommand() async {
        speech.stop()

        // The Accessibility route only: it posts no events. The pasteboard
        // route's synthetic ⌘C would trip our own interruption watch, so it
        // waits until the key is up (`endCommand`).
        commandSelection = SelectionReader.selectedTextViaAccessibility()
        commandIsCapturing = false
        commandHold = CommandHold()
        liveText = ""
        status = .listening

        // No microphone is not a failure here. A silent hold means "fix", and
        // fixing needs no audio — a Mac Studio with no mic still gets it.
        guard AVCaptureDevice.default(for: .audio) != nil else {
            overlay.show(mode: .command)
            return
        }

        do {
            try await startCapture(
                listeningMode: .command,
                vocabulary: [],
                pressed: ContinuousClock().now,
                onTranscript: { [weak self] text in self?.commandTranscriptArrived(text) }
            )
            commandIsCapturing = true
        } catch {
            audio.stop()
            overlay.show(mode: .command)
        }
    }

    /// A live transcript arrived mid-hold. The moment it holds a command
    /// word, the command runs — the key does not have to come up (GDR-0014).
    private func commandTranscriptArrived(_ text: String) {
        guard gesture == .command else { return }
        // Taught corrections first: a stable mis-hearing of a command is
        // teachable like any other word (GDR-0011).
        let heard = CorrectionTable.applied(vocabularyStore.corrections, to: text)
        guard let command = commandHold.heard(heard) else { return }

        // Committed. The shortcut watch has done its job, and our own ⌘C and
        // ⌘V below must not be mistaken for the user typing a shortcut.
        hotkey.endInterruptionWatch()
        overlay.update(mode: .working(command.progressLabel), text: "")

        // Unstructured on purpose: this runs inside the transcript task,
        // which is cancelled as capture stops, and the command must outlive it.
        Task { [weak self] in
            guard let self else { return }
            await self.dropCommandCapture()
            await self.perform(command)
        }
    }

    /// The key came up. If a command already fired this does nothing; if not,
    /// the final transcript decides, and silence means fix.
    private func endCommand() async {
        guard gesture == .command else { return }
        if commandHold.beginRelease() == .alreadyHandled { return }

        let spoken = await finishCommandCapture()
        let heard = CorrectionTable.applied(vocabularyStore.corrections, to: spoken)
        switch commandHold.resolve(finalTranscript: heard) {
        case .alreadyHandled:
            return
        case .unrecognised(let words):
            commandSelection = nil
            finishCommand(
                showing: .error("Heard “\(words)” — say fix, explain or shorten."), for: .seconds(3.5))
        case .run(let command):
            overlay.update(mode: .working(command.progressLabel), text: "")
            await perform(command)
        }
    }

    /// Runs a decided command on the selection — the same path whether it
    /// fired on the word or on the release.
    private func perform(_ command: VoiceCommand) async {
        defer { commandSelection = nil }

        // The shortcut watch is gone, so the pasteboard route is safe even if
        // the key is still physically held.
        var selection = commandSelection
        if selection == nil { selection = await SelectionReader.selectedText() }
        guard let selection else {
            finishCommand(showing: .error("Select some text first."), for: .seconds(2))
            return
        }

        status = .polishing
        lastExplanationPush = nil

        let outcome = await transformer.run(
            command,
            on: selection,
            corrections: vocabularyStore.corrections,
            acronyms: vocabularyStore.acronyms,
            onExplanation: { [weak self] partial in self?.showExplanationSoFar(partial) }
        )
        switch outcome {
        case .replacement(let text):
            // Hide before pasting, as dictation does. The selection is still
            // active, so the paste replaces it — and ⌘Z puts it back.
            overlay.hide()
            inserter.insert(text)
            lastInserted = text
            becomeIdle()
        case .explanation(let text, let source):
            finishCommand(
                showing: .explanation(caption: source.caption),
                text: text,
                for: ExplanationTiming.displayDuration(for: text)
            )
        case .unchanged(let message):
            finishCommand(showing: .notice(message), for: .seconds(2))
        case .failure(let message):
            finishCommand(showing: .error(message), for: .seconds(3.5))
        }
    }

    /// The card opens with the first streamed words. Throttled: the model
    /// writes faster than a panel should be re-laid-out, and nobody reads at
    /// twenty frames a word.
    private func showExplanationSoFar(_ partial: String) {
        let now = ContinuousClock.now
        if let last = lastExplanationPush, now - last < .milliseconds(70) { return }
        lastExplanationPush = now
        overlay.update(
            mode: .explanation(caption: TextTransformer.ExplanationSource.model.caption), text: partial)
    }

    /// Stops listening once a command fired on the word: the rest of the
    /// transcript is not needed, so the session is dropped, not finalized.
    private func dropCommandCapture() async {
        guard commandIsCapturing else { return }
        commandIsCapturing = false
        audio.stop()
        cancelDisplayTasks()
        await transcriber.abandonDictation()
    }

    /// Ends the command's speech session and returns what was said — empty
    /// when nothing was, or when there was no microphone to say it into.
    private func finishCommandCapture() async -> String {
        guard commandIsCapturing else { return "" }
        commandIsCapturing = false

        let heardAudio = audio.hasDeliveredAudio
        audio.stop()
        let transcript = (try? await transcriber.finishDictation()) ?? ""
        cancelDisplayTasks()
        return heardAudio ? transcript : ""
    }

    private func abandonCommand() async {
        _ = await finishCommandCapture()
        commandSelection = nil
        overlay.hide()
        becomeIdle()
    }

    private func finishCommand(showing mode: OverlayView.Mode, text: String = "", for duration: Duration) {
        overlay.update(mode: mode, text: text)
        overlay.hide(after: duration)
        becomeIdle()
    }

    // MARK: - Reading aloud

    /// How long left Option must be held before it means "stop" instead of
    /// "start or speed up".
    private static let readHoldThreshold: Duration = .milliseconds(350)

    /// Left Option went down. Reading is tap-driven, so nothing happens yet
    /// — but a hold past the threshold means stop, and that must not wait
    /// for the key to come back up: a listener reaching for the stop key
    /// wants silence immediately, not whenever they happen to let go.
    private func readKeyWentDown() {
        readHoldFired = false
        readHoldTask?.cancel()
        readHoldTask = Task { [weak self] in
            try? await Task.sleep(for: Self.readHoldThreshold)
            guard !Task.isCancelled, let self else { return }
            self.readHoldFired = true
            guard self.speech.isReading else { return }
            self.speech.stop()
            self.overlay.hide()
        }
    }

    /// Left Option came up. The flag — not the task's cancellation state,
    /// which is always true once cancelled — says whether the hold already
    /// fired. If it didn't, this was a tap.
    private func readKeyWentUp() async {
        readHoldTask?.cancel()
        readHoldTask = nil
        guard !readHoldFired, !isDictating else { return }

        if speech.isReading {
            speedUpReading()
        } else {
            await startReading()
        }
    }

    private var isDictating: Bool {
        status == .listening || status == .polishing
    }

    private func startReading() async {
        guard !isDictating else { return }

        overlay.show(mode: .reading(speed: ReadingSpeed.label(for: ReadingSpeed.slowest)))

        guard let text = await SelectionReader.selectedText() else {
            overlay.update(mode: .error("Select some text first."))
            overlay.hide(after: .seconds(2))
            return
        }

        speech.onFinish = { [weak self] in
            self?.overlay.hide()
        }
        speech.read(text)
        overlay.update(mode: .reading(speed: ReadingSpeed.label(for: speech.speedMultiplier)))
    }

    private func speedUpReading() {
        let climbed = speech.faster()
        let label = ReadingSpeed.label(for: speech.speedMultiplier)
        overlay.update(mode: .reading(speed: climbed ? label : "\(label) max"))
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

    /// Teaches a correction; false when there was nothing to teach.
    @discardableResult
    public func teachCorrection(heard: String, meant: String) -> Bool {
        vocabularyStore.teach(heard: heard, meant: meant)
    }

    public func forgetCorrection(_ correction: Correction) {
        vocabularyStore.forget(correction)
    }

    /// Defines a term for "explain"; false when there was nothing to define.
    @discardableResult
    public func defineAcronym(term: String, meaning: String) -> Bool {
        vocabularyStore.define(term: term, meaning: meaning)
    }

    public func forgetAcronym(_ acronym: Acronym) {
        vocabularyStore.undefine(acronym)
    }

    // MARK: - Helpers

    private func becomeIdle() {
        gesture = nil
        liveText = ""
        status = .idle
    }

    private func showFailure(_ error: Error) {
        overlay.update(mode: .error(error.localizedDescription))
        overlay.hide(after: .seconds(2.5))
        gesture = nil
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
