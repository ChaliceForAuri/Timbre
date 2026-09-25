# Product Hunt listing

- **Kind:** listing
- **Status:** draft — prepared, not necessarily launched the same day
- **Order:** 2

Everything the Product Hunt form asks for, in the order it asks. Tagline is limited to 60 characters; the description to 260.

## Copy

**Name:** Timbre

**Tagline:** Mac dictation that never touches the internet

**Description:** Hold a key, talk, release: cleaned-up text lands wherever your cursor is, cleaned by Apple's on-device model. Read any selection aloud, fix or shorten it by voice, say a to-do into Reminders. Zero network requests, no account, free.

**Topics:** Mac, Productivity, Privacy, Artificial Intelligence, Developer Tools

**First comment (maker):**

Hi Product Hunt — I'm Hugo, and I made Timbre because every dictation app I tried wanted my voice on its servers.

Timbre runs on Apple's on-device speech and language models, so out of the box it makes no network requests at all. That's a falsifiable claim, not a policy: run Little Snitch or `nettop -p Timbre` and the list stays empty. The only request it can ever make is an update check you turn on yourself, and the site lists it.

What it does:
• Hold right Option and talk: filler gone, punctuation right, your phrasing intact, pasted into any app.
• Tap left Option: hear a selection read back, with the best voice on your Mac.
• Hold right Command on a selection: say fix, shorten, plain or explain. A silent hold means fix. Command-Z undoes.
• Hold right Command with nothing selected: say a to-do and it lands in Apple's Reminders, dated.

It learns your words — vocabulary, corrections, definitions — in a dictionary that lives on your Mac.

Free for personal use. macOS 26, Apple Silicon, Apple Intelligence on. Source on GitHub, and every product decision is a written record you can read. Happy to answer anything.

## Notes

- Gallery: three screenshots in light mode (pill mid-dictation, explanation card, Settings › Dictionary), the same three in dark, then the 30-second clip if recorded.
- Launch at 00:01 PT on a Tuesday, Wednesday or Thursday.
- The "Zero network requests" line draws the "what about the speech model download" question; the answer is on /network under "What macOS does on Timbre's behalf".
