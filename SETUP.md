# Spoke — a free, local, native dictation app

A Wispr Flow replacement built entirely on Apple's on-device stack. No account,
no subscription, no network. Transcription runs on `SpeechAnalyzer`, cleanup
runs on the Foundation Models on-device LLM.

---

## Before you start: check your Mac

This is a hard gate. Run these two checks first.

```bash
sw_vers                     # ProductVersion must be 26.0 or higher
sysctl -n machdep.cpu.brand_string   # must say "Apple M…", not Intel
```

Also confirm Apple Intelligence is on: **System Settings › Apple Intelligence & Siri**.
If it's off, the cleanup layer silently falls back to raw transcripts.

If you're on Intel or below macOS 26, stop here and tell me — the architecture
changes (we'd swap in whisper.cpp locally) and I'll rewrite the two affected files.

---

## Setup (about 5 minutes)

1. **Install Xcode** from the Mac App Store if you haven't. Open it once and let
   it install components.

2. **New project:** Xcode → File → New → Project → macOS → **App**.
   - Product Name: `Spoke`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck Core Data / Tests.

3. **Delete the two files Xcode generated** — `ContentView.swift` and its own
   `SpokeApp.swift` (move to trash). Then **drag in all nine `.swift` files**
   from the `Spoke/` folder, including our own `SpokeApp.swift` which replaces
   the deleted one. Check "Copy items if needed".

4. **Set the deployment target:** select the project in the sidebar → target
   `Spoke` → General → Minimum Deployments → macOS **26.0**.

5. **Turn off the sandbox.** Target → Signing & Capabilities → hover over
   "App Sandbox" → click the ⊗ to remove it.
   *Why: the sandbox blocks the synthetic Cmd+V used to paste into other apps.
   You'd re-add it later with entitlements if you shipped to the App Store —
   which, for this app, you probably won't. Direct distribution is the norm here.*

6. **Add permission strings.** Target → Info → add these rows:

   | Key | Value |
   |---|---|
   | `NSMicrophoneUsageDescription` | `Spoke listens when you hold the dictation key.` |
   | `NSSpeechRecognitionUsageDescription` | `Spoke transcribes your speech on-device.` |
   | `LSUIElement` | `YES` |

   `LSUIElement` is what makes it a menu bar app with no Dock icon.

7. **Build and run** (⌘R). Grant Microphone when asked. For Accessibility,
   macOS will show a dialog — approve it in **System Settings › Privacy &
   Security › Accessibility**, then **quit and relaunch the app**. The trusted
   state is unreliable after a live toggle, and nothing errors when it's
   wrong — the hotkey just silently does nothing. Always relaunch.

8. **Try it.** Click into any text field, hold **right Option**, speak, release.

---

## What each file does

| File | Role | The interesting part |
|---|---|---|
| `SpokeApp.swift` | App shell, menu bar, settings | `MenuBarExtra` scene |
| `DictationController.swift` | Orchestrates the pipeline | The whole flow in ~40 lines |
| `AudioCapture.swift` | Mic → PCM buffers | Format conversion, where most apps break |
| `Transcriber.swift` | Apple's streaming speech model | Replaces Wispr's cloud tier |
| `TextPolisher.swift` | On-device LLM cleanup | **The actual product. Tune this.** |
| `HotkeyMonitor.swift` | Hold-to-talk right Option | Needs Accessibility |
| `TextInserter.swift` | Paste into any app | Clipboard save/restore |
| `OverlayController.swift` | The floating pill's window | Non-activating panel, caret positioning |
| `OverlayView.swift` | The pill's contents | Live text + audio waveform |

---

## If the first build fails

I couldn't compile this (no Xcode where I wrote it), so budget 10 minutes for
small fixes. The likely ones, in order:

**1. Sendable errors around `AVAudioPCMBuffer`.**
Swift 6's strict concurrency doesn't consider audio buffers safe to pass
between threads, even though this usage is fine. Easiest fix while learning:
target → Build Settings → search "Swift Language Version" → set to **5**.
You get the concurrency model without the hard errors. Switch to 6 later once
the concepts have landed.

**2. `AXIsProcessTrusted` not found.**
Add `import ApplicationServices` at the top of `HotkeyMonitor.swift`.

**3. Anything else.** Paste me the exact error text — Xcode's messages are
verbose but precise, and reading them is genuinely half of learning this stack.

I verified every Speech and FoundationModels call against Apple's current
documentation, so API-shape errors should be rare; concurrency annotations are
the more likely culprit.

> **Worth knowing:** macOS 27 added `SpeechTranscriber(locale:preset:)` with
> presets like `.progressiveTranscription`, which collapses the four option sets
> in `Transcriber.swift` into one argument. I used the explicit form because it
> shows you what's actually being configured. Simplify once it works.

---

## Coming from Flutter / React Native

You already know 80% of this. Here's the map:

| You know | Swift equivalent | Difference that will bite you |
|---|---|---|
| `Widget` / JSX component | `struct X: View` | Views are structs (value types), recreated constantly. Never store state in them directly. |
| `setState` / `useState` | `@State` | Same idea, but `@State` must live in the view that *owns* the data. |
| Provider / Redux / Zustand store | `@Observable final class` | Just mutate properties. SwiftUI tracks which views read which property automatically — finer-grained than RN. |
| `Future` / `Promise` | `async`/`await` | Nearly identical syntax. No `.then()` chains needed. |
| `async` function anywhere | `Task { }` | You can't call `await` from sync code. `Task { }` is the bridge. |
| No thread rules | `@MainActor` | **The big new concept.** UI code must run on the main actor. The compiler enforces it. If you see "call to main actor-isolated method in a synchronous nonisolated context", you need a `Task { @MainActor in … }`. |
| Mutex / careful shared state | `actor` | A class that serializes access to its own state. `Transcriber` is one. That's why you `await` its methods. |
| `null` / `undefined` | `Optional` (`String?`) | Stricter. `guard let x else { return }` is the idiom you'll type most. |
| Hot reload | Xcode Previews (`#Preview`) | Not as good. You'll rebuild more. Accept it. |
| `package.json` | Swift Package Manager | You need zero dependencies for this project. |

**The single biggest adjustment:** Swift's concurrency checking is compile-time,
not runtime. Errors that would be a race condition crash in RN become build
errors here. It's frustrating for the first week and then it's a superpower.

---

## Where to take it next

Ordered by impact on "gets people off Wispr Flow":

1. **Tune the prompt in `TextPolisher.swift`.** Dictate 20 real messages, look at
   what the model gets wrong, adjust the instructions. This is 80% of perceived
   quality and it costs you nothing but iteration.
2. **Auto-learn vocabulary.** When the user edits inserted text within a few
   seconds, diff it and add the corrections to `vocabulary` automatically.
   Nobody does this well locally — it's your wedge.
3. **Per-app tone profiles.** You already pass the app name; let users set
   "Slack = casual, Mail = formal" explicitly.
4. **Command mode.** Select text, hold a different key, say "make this shorter".
   Same `TextPolisher` with different instructions.
5. **Notarize and ship it.** Free, on the web, no account. That's the whole
   go-to-market.

*(Done: the floating live-text overlay — `OverlayController.swift` and
`OverlayView.swift`.)*

## Known gaps vs Wispr Flow (be honest about these)

- **Multilingual.** Apple's on-device model is weaker outside English and has no
  real code-switching. Don't chase this; position as English-first.
- **No iPhone.** iOS can't replace system dictation — a keyboard extension is the
  only route and it's memory-constrained. Mac-only is a legitimate choice.
- **No sync.** Which is also a privacy feature. Frame it that way.

---

## After the first build: move into the Code tab

Once the project opens in Xcode, stop editing these files by hand and stop
shipping zips around. Open the **Code** tab in the Claude desktop app and point
a local session at this folder.

It runs on your actual Mac, so it can run `xcodebuild`, read the real compiler
errors, and fix them without you relaying anything. It also gives you visual
diffs before accepting changes, parallel sessions on automatic git worktrees,
and an integrated terminal — and it reads the `CLAUDE.md` in this folder
automatically, so it starts with full project context.

Set up git first so you can undo experiments:

```bash
git init && git add -A && git commit -m "Spoke: local dictation with live overlay"
```

The standalone `claude` CLI works identically if you prefer the terminal — same
engine, same config files. The CLI additionally supports scripting (`--print`),
CI pipelines, and agent teams, none of which you need yet.

Keep using Cowork (this chat) for research, positioning, naming, and documents —
it can't compile Swift, but it's better for everything that isn't code.
