# Timbre, the whole product

*2026-10-11 · Status: proposed map, for the decisions below. Constraining
records: GDR-0001, GDR-0006, GDR-0010, GDR-0013. This document is where
the product is planned as one thing; each piece that lands still gets its
own record.*

Timbre started as a key you hold to talk. It is about to become the place
where the words you use get better: spelling, vocabulary, phrases,
acronyms. This map lays out every piece, which surface owns it, where its
data lives, and what crosses the one boundary the product is built on —
so nothing is built twice and nothing falls between two surfaces.

## 1. Three pillars

| Pillar | What it is | Today |
|---|---|---|
| **Speak** | Dictate, fix/shorten/plain/explain, read aloud, say a to-do. Everything on-device, nothing leaves the Mac. | Shipped (0.3.x, 0.4.0 forming) |
| **Learn** | The Bank — words, acronyms, phrases, spellings you are collecting — plus a profile that makes "explain" right for your industry, a word of the day, and practice that uses your own voice. | Vocabulary, corrections and definitions exist as three Settings lists. Nothing else yet. |
| **Run** | Backstage: releases, decisions, plans, evals, launch, architecture, brand. The business, in one place. | Shipped |

Speak is the wedge and stays the wedge: *dictation that never leaves your
Mac*. Learn is the reason to open the app when you are not dictating, and
the reason to want it on your phone. Run is ours.

## 2. Surfaces

| Surface | Owns | Does not do |
|---|---|---|
| **Mac app** | Everything in Speak. The Bank's capture side: a word you taught, a correction, a definition, a word you had explained — each lands in the Bank. The Mac is where words are *met*. | Nothing cloud-side. Zero network requests (GDR-0001/0013). |
| **iPhone app** (planned) | The Bank in your pocket: review, practise, word of the day, add a word you heard. The phone is where words are *kept*. | No dictation into other apps (iOS cannot), no commands. It is a companion, not a port. |
| **Website** | The claim, the download, the network list. | Accounts, sync, anything personal. |
| **Backstage** | Running the product. | Anything a user sees. |
| **Cross-platform client** (open) | A Bank on Android or the web, if ever. | Only exists if there is an account to sign into — see §4. |

## 3. The Bank

One store replaces three lists. Every entry has a *kind*, and the kinds
are exactly the four things Hugo wants to get better at, plus the one the
app already keeps:

| Kind | Example | Where it comes from | What uses it |
|---|---|---|---|
| **word** | *ephemeral* — short-lived | explain on a word; added by hand; word of the day | the polisher's vocabulary; practice |
| **acronym** | *ADR* — Architecture Decision Record | define in Settings; explain's answer, kept | explain answers from it first (GDR-0012) |
| **phrase** | *a canary in the coal mine* — an early warning | explain on a selection; added by hand | practice; the polisher leaves it intact |
| **spelling** | *definately → definitely* | fix corrected it; the spell checker fallback | practice ("spell it"); a correction if it keeps happening |
| **correction** | *timber kit → TimbreKit* | taught in Settings; one day from your own edits | CorrectionTable, before the model (GDR-0011) |

An entry carries: the term, its meaning, an example sentence, where it
came from (which app, dictated or typed, on which day), tags including the
industry it belongs to, a *strength* that practice raises and time lowers
(the spaced-repetition number), and its history. Nothing in an entry is
ever transmitted by the Mac app; the entry is the user's.

**Profile.** Industry (one or more), role, first language. Used in two
places: explain's prompt ("the reader works in healthcare, so *PA* means
physician assistant before it means personal assistant"), and the word of
the day's choice of lists. Lives in the Bank, syncs with it.

## 4. The one boundary, and the sync decision

The Mac binary makes no network requests. That is the claim on the
headline, falsifiable with a network monitor, and the entire competitive
wedge (GDR-0001, GDR-0006, GDR-0013). The Bank wants to be on the phone.
There are two ways to get it there, and they are not equal:

| | **A. iCloud** | **B. A Timbre account** |
|---|---|---|
| How | CloudKit, private database, the user's own iCloud. Apple's daemons do the syncing; the binary still makes zero requests. GDR-0010 already accepted this shape for the dictionary. | Supabase (already running Backstage's auth), the apps call it. |
| Reaches | Mac and iPhone (and iPad, Watch). | Anything with a browser. |
| Needs | The iCloud capability on the App ID (done), a CloudKit container, an entitlement. No server, no cost, no account to create. | Sign-up, sessions, a schema with row-level security, a privacy policy, GDPR handling, uptime. |
| Costs the claim | Nothing. `/network` stays at one entry. | The headline needs a second asterisk: the app phones home when you sign in. Amends GDR-0013; `/network` gains entries. |
| When it is right | Now. | When a non-Apple client is real and wanted — not before. |

**Recommendation:** A first, and design the Bank's store so that B is a
second backend behind the same interface, not a rewrite. "Apple pure" is
not a lite tier; it is the product. B becomes a decision the day there is
an Android or web Bank to sign into, and it gets its own record then.

## 5. Learning, using what Timbre already does

Practice should use Timbre's own abilities rather than becoming a flash-card
app with a microphone bolted on:

- **Spell it.** The phone shows the meaning; you say the word, then spell it aloud. The on-device recogniser hears both.
- **Say it.** The phone shows a word or phrase; you use it in a sentence, out loud. The polisher's model judges whether it was used in its meaning — a guardrail-scored check, like every command (GDR-0012's rule for new verbs applies to new drills).
- **Explain it.** The card you saw on the Mac, now a question: what does *ADR* stand for?
- **Word of the day.** Chosen from the Bank's weakest entries first, then from a bundled list for the profile's industry. Delivered as a local notification on Mac and iPhone. Saying it in a dictation that day marks it met.
- **Gamification, the private kind.** Strength bars, streaks, a weekly review. No leaderboard, no sharing, nothing that needs a server.

## 6. No gaps, no duplication

| Capability | Owner | Store | Sync |
|---|---|---|---|
| Dictation, commands, read aloud, to-dos | Mac app | — | — |
| Capturing a Bank entry from use | Mac app | Bank (local) | iCloud |
| Browsing, editing the Bank | Mac Settings → *Bank*; iPhone | Bank | iCloud |
| Profile | iPhone and Mac, same screen | Bank | iCloud |
| Practice, word of the day | iPhone first; Mac menu later | Bank (strength, history) | iCloud |
| Usage count | Mac app | UserDefaults | never (GDR: this Mac only) |
| Dictation capture for tuning | Mac app | jsonl on disk | never (GDR-0004) |
| Releases, decisions, plans, evals, launch, architecture, brand | Backstage | the repo | CI |

Shared logic lives in one place: the Bank's model, parsing and practice
scoring move into a platform-neutral `TimbreCore` package that the Mac app
and the iPhone app both import; `TimbreKit` keeps the macOS-only pipeline.
That split is a record of its own (an ADR) before the first iOS line.

## 7. Phases

| Phase | Delivers | Proof |
|---|---|---|
| 0 | 0.4.0: icon, disk image, to-dos, plain, live typing. Launch. | Public. |
| 1 | **The Bank on Mac.** One store with kinds; Settings › Dictionary becomes *Bank*; explain, fix and define write to it; export to a file. | Every existing list migrates; nothing lost. |
| 2 | **`TimbreCore` + iCloud sync.** The split, the CloudKit container, sync on two Macs. | Teach on one Mac, see it on the other, `nettop` still empty. |
| 3 | **Timbre for iPhone.** The Bank, profile, word of the day, Spell it. | On the phone a minute after teaching on the Mac. |
| 4 | **Practice that listens.** Say it, Explain it, strength and streaks. | A drill corpus the harness can score. |
| 5 | **Profile-aware explain** on the Mac. | A commands corpus case per industry. |
| — | *Account and cross-platform.* | Decided when phase 3 has users asking. |

## 8. Decisions this map asks for

1. **Sync by iCloud first, account later or never** (§4).
2. **The iPhone app is a companion** — the Bank and practice — not a dictation app (§2).
3. **One Bank, five kinds**, replacing the three Settings lists (§3).
4. **`TimbreCore`** split before the first iOS file (§6).
5. **Practice uses the voice** — drills are scored like commands, with a corpus (§5).
