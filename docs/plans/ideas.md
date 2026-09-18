# Ideas, prioritised

- **Date:** 2026-09-18
- **Order:** 2

Everything worth doing that is not on the launch list, in the order it earns its place. "Now" is launch week and lives in that plan; this is what comes after, and why.

## Next — the first things after launch

1. **Teach by voice.** Select the wrong word, hold right ⌘, say "correct", then say what you meant: the correction table fills itself without a trip to Settings. Closes the loop GDR-0011 opened; roadmap item 2.
2. **Define by voice.** Same gesture, "define": a term with no definition gets one spoken in. Explain then answers from it forever.
3. **Snippets.** The correction table already is one: "my email" → the address, "my sign-off" → three lines. Closes issue #21 (spoken email addresses). Needs only Settings copy and a multi-line meant field.
4. **Rich text survives fix.** Bold, links and lists in a selection come back with their formatting, the way Tidy does it — read the selection as HTML, correct the text, re-attach runs, paste an HTML fragment. Until then a fix on formatted text flattens it; the GDR says so.
5. **Rebindable keys.** Some people have no right ⌥ on a compact keyboard, or use right ⌘ for ⌘-Tab. Offer a small set of alternatives per gesture (Fn, Caps Lock via Karabiner-style remap is out) rather than a free binder.
6. **Per-app tone profiles.** Mail formal, Slack casual, Xcode literal. The app name already reaches the polisher; this is a table and a sentence in the prompt. Roadmap item 3, and a good demo.
7. **iCloud sync of the dictionary** (GDR-0010, accepted). Vocabulary, corrections, definitions — off by default, key-value store, needs the entitlement and profile.

## Later — worth it, not yet

8. **Brain dump.** Hold a key, ramble for a minute, get a cleaned note appended to today's file in a folder you choose (iCloud Drive syncs it if you like). With the Reminders capture, action items can be pulled out of the ramble.
9. **Daily brief, spoken.** Left ⌥ with nothing selected reads today's Reminders and the top of the note. Voice out for the ADHD morning.
10. **Auto-learn corrections from edits.** Watch, briefly and locally, what the user changes right after a paste and offer it as a correction. The hard part is doing it without feeling watched; GDR-0004's opt-in shape is the model.
11. **More verbs, each with a guardrail.** "Longer" (expand notes into prose), "translate" (on-device, English only for now), "list" (prose into bullets). GDR-0012's rule: no verb without a check that can score it.
12. **Feedback from the app.** A menu item that opens a pre-filled GitHub issue with macOS version, app name and a redacted before/after — the same guidance Tidy gives, one click. Still no network from the binary; the browser does the work.
13. **University in the app.** A "Why does it need Accessibility?" link that opens the relevant Backstage module.

## Not doing, and why

- **Cloud fallback for weak Macs.** GDR-0001 and GDR-0006: there is no cloud, because there is no cloud.
- **Analytics, even opt-in.** GDR-0006: privacy is not a tier.
- **Punctuation commands ("period", "comma").** GDR-0003: the polisher makes them unnecessary and they are ambiguous English.
- **An open spoken instruction in command mode.** GDR-0012: no guardrail can score "make this friendlier".
- **Switching the speech engine for vocabulary.** ADR-0008: measured, not worth it.
