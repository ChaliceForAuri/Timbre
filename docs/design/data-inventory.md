# The data inventory: what Timbre holds, where, and why

*2026-10-22 · Status: the record of processing for the app, the companion,
iCloud sync, the website and the development side, kept current by the
review (GDR-0030): a change that touches a row updates the row in the same
pull request. Article 30 of the GDPR asks for this record; SOC 2's privacy
criteria ask for the same facts. Where something is designed but not built,
the row says so.*

## 0. Who holds what

| System | Who holds the data | Our role | Processors |
|---|---|---|---|
| The Mac app, the iPhone app, the Watch app | The user, on their own devices | None: we never receive it. The user is the only holder. | None. Apple's on-device frameworks process it on the device. |
| iCloud sync of the Library | The user, in their own iCloud account | None: the private CloudKit database is readable only by the user's devices. | Apple, as the user's own provider under the user's iCloud terms. |
| The website and Backstage | Hugo Pretorius, as the site's controller | Controller | Vercel (hosting, logs), Supabase (auth, database), GitHub (repository, issues, CI). Langfuse and Stripe are designed, not in use. |
| Development and release | Hugo Pretorius | Controller of his own material | GitHub, Apple (notarisation, developer account), Anthropic (the review's model, under the maintainer's account). |

## 1. The Mac app

| Data | Where | Purpose | Default | Lifetime and erasure | Leaves the Mac? |
|---|---|---|---|---|---|
| The Library: words, acronyms, phrases, spellings, corrections, each with a meaning, an example, provenance, tags, and the events strength is derived from; the profile (field, role, first language) | `~/Library/Application Support/Timbre/library.json`, one document written atomically | Bias transcription, correct the polisher, answer explain, pick and practise the word of the day | On: it is the product | Until the user removes an entry (`forgot` is a tombstone), deletes the file, or uninstalls. Settings › Library shows every entry; Export writes the whole Library as one JSON file; Import merges. | Only if the user turns on iCloud sync (§3) |
| Dictation capture: the raw transcript, the polished text, the app name, timings | `~/Library/Application Support/Timbre/dictations.jsonl` | The user's own corpus; `timbre-eval --import` turns it into a corpus on the developer's own Mac only | Off (GDR-0004) | Until Delete All, from the same screen that turns it on; Show in Finder reveals the file | Never |
| Microphone audio | Memory, during a hold of the key | On-device transcription with `SpeechAnalyzer` | Granted by the user once | Discarded as it is transcribed; never written | Never |
| The pasteboard and the focused text field | Memory, during one insertion | Paste the result; replace the live-typed run | Needs Accessibility, granted by the user | Snapshot, set, paste, restore; nothing kept | Never |
| The selection, for read-aloud and command mode | Memory | Read it aloud; fix, explain, shorten, plain | Needs Accessibility | Discarded after the command | Never |
| The explanation card, the overlay, the word-of-the-day card | Memory; the day's example sentence is kept for the day | Show the result | On | The card rebuilds daily | Never |
| Settings | `UserDefaults` for `dev.hugopretorius.Timbre` | Preferences: reading speed, voice, toggles | On | Until the user resets them | Never |
| The word-of-the-day notification | The system's notification centre, local | The morning word | Off (GDR-0027) | Delivered and gone; no server | Never |
| The update check: one `GET` for `appcast.json` on our site | Vercel's request logs (IP address, user agent, time) on the site's side | Find a newer version; verify and install on request | Off; a menu item, or a daily check the user turns on (GDR-0013) | Vercel's log retention, not ours; no identifier, no query string, no cookie | Yes: this is the only request the binary can make |
| Reminders | The user's Reminders database (Apple), the "Timbre" list | A spoken to-do lands in Reminders (GDR-0016) | Asked for on the first spoken to-do | The user's, in Reminders | To the user's iCloud only if their Reminders sync; not through us |

## 2. The iPhone and the Watch

| Data | Where | Purpose | Default | Lifetime and erasure | Leaves the device? |
|---|---|---|---|---|---|
| The Library | The app group container `group.dev.hugopretorius.Timbre` | Same as the Mac | On | Same as the Mac: Settings, Export, Forget | Only with iCloud sync on |
| `today.json`: today's word, its strength and whether it was met | The app group container, read by the widgets | The widget, the Lock Screen, the complication show a word without reading the Library (ADR-0016) | On | Rewritten on every rebuild; deleted with the app | Never |
| Hold-to-talk audio | Memory | On-device transcription with `SpeechAnalyzer` | Granted once | Discarded as transcribed | Never |
| The Watch's text input | Apple's system dictation and scribble UI | A spoken to-do on the wrist | Granted once | Apple's | Apple's dictation may use Apple's servers under the user's own Siri & Dictation setting; the Watch app's copy says so. Timbre adds nothing to it. |
| The to-do queue in transit | WatchConnectivity, device to device | The Watch captures, the iPhone files (GDR-0029) | On | Queued on the Watch until the phone is reachable, then dropped | Watch to the user's own iPhone, through Apple's transport, never through us |
| Reminders | The user's Reminders database | As on the Mac; read-only on the Watch | Asked once | The user's | As on the Mac |

## 3. iCloud sync of the Library

| Data | Where | Purpose | Default | Lifetime and erasure | Who can read it |
|---|---|---|---|---|---|
| The Library's events and entries and the profile, as immutable records in the zone "Library" | The user's private CloudKit database in container `iCloud.dev.hugopretorius.Timbre` | The same Library on every device (ADR-0017) | Off (GDR-0010) | Until the user turns sync off and removes the app's data in their iCloud settings (System Settings › iCloud › Manage Storage). An in-app "delete from iCloud" is not built; see §6. | The user's devices only. The private database is not readable by the developer. Advanced Data Protection, when the user turns it on, end-to-end encrypts it. |
| Sync state | `~/Library/Application Support/Timbre/library-sync.json` | Where CKSyncEngine left off | Off | Deleted with the file | Never |

Never synced, by rule: dictations, transcripts, captures, timings
(GDR-0010). The schema is forever: no field renamed, retyped or removed.

## 4. The website and Backstage

| Data | Where | Purpose | Lawful basis | Lifetime and erasure | Status |
|---|---|---|---|---|---|
| Request logs: IP address, user agent, path, time | Vercel | Serve and secure the site; the same logs receive the app's update check | Legitimate interest in running the site | Vercel's default retention; not exported | In use |
| Releases, the appcast, the University | Vercel, static files | Distribute the app and the learning material | None needed: nothing is collected | — | In use |
| The Backstage login | Supabase auth: one owner email (the maintainer's) and a session cookie | Gate the lab | The maintainer's own account | Until the maintainer logs out or deletes the account | In use; no public sign-up |
| Page views: path, referrer, country, time; no identifier, no cookie | Supabase table `page_views` | Know what is read | Legitimate interest; no consent needed because no identifier is set | Design: aggregate after 90 days, delete rows | Designed, not built (backstage.md §9) |
| Feedback: body, app context, a GitHub issue number | GitHub issues, mirrored to Supabase `feedback` | Hear from users who choose to write | Consent, by submitting the form | Until the issue is closed and the row deleted on request | Designed, not built (backstage.md §8) |
| Eval runs and results | Supabase `eval_runs`, `eval_results` | Measure the pipeline against synthetic corpora | None needed: no personal data | Kept as the measurement record | Designed, not built |
| Dictation samples | Supabase `dictation_samples` | The maintainer's own opt-in exports, for evaluation | The maintainer's own data | Deleted by the maintainer | Designed, not built; never anyone else's |
| Customers: email, Stripe customer id, product, status | Supabase `customers`, Stripe | Sell the product | Contract | Per the customer agreement, to be written | Deferred |
| LLM traces | Langfuse | Debug the polisher's prompts on synthetic input | None needed | Per Langfuse's retention | Designed, not built |

The site sets no cookie except the lab's session cookie, which is strictly
necessary for the one person who logs in; there is no consent banner because
nothing needs one. A privacy notice for the site's logs and the lab's login
is not yet published; see §6.

## 5. Development and release

| Data | Where | Purpose | Notes |
|---|---|---|---|
| The repository: code, records, design docs, the University, synthetic corpora, `say`-generated audio fixtures | GitHub, public | The product and its book | No real dictation, Library, email or screenshot of real data is ever committed (review C5). `packages/TimbreKit/Fixtures/real-corpus.json`, the import of the maintainer's own capture, is ignored by git. |
| CI logs | GitHub Actions | Build and test on every pull request | Build output only; no personal data in the corpora |
| The review evidence | A review comment and a commit status on each pull request; a local copy under `.review/`, ignored by git | GDR-0030 | The diff and the files the model reads go to Anthropic's API under the maintainer's Claude account; no user data is in the repository, so none goes |
| The release | Apple's notarisation service receives the binary; the signed zip and `appcast.json` are published on the site | Distribute a verified build | The code requirement names the team; changing it strands every installed copy (ADR-0010) |
| Signing identities and secrets | The maintainer's keychain; Vercel environment; GitHub Secrets | Sign, deploy | Never in the repository (review B4) |

## 6. Rights, and the gaps

| Right | How it is met |
|---|---|
| Access (Art. 15) | Settings › Library lists everything; the Library is one readable JSON file; captures are a readable JSON Lines file with Show in Finder |
| Portability (Art. 20) | Settings › Library › Export writes the whole Library as JSON; Import merges it elsewhere |
| Rectification (Art. 16) | The edit sheet on every entry |
| Erasure (Art. 17) | Forget an entry (a tombstone that wins a merge), Delete All captures, delete the files, uninstall; iCloud through Apple's settings (gap below) |
| Objection and consent (Art. 7, 21) | Every optional flow is off by default: capture, sync, update checks, the notification, Reminders access is asked on first use |
| Breach notification (Art. 33) | No server of ours holds user data; the site's data is the maintainer's own and Vercel's logs |

Known gaps, to be closed before the product takes customers:

1. **No in-app "delete from iCloud".** The user can remove the app's data in
   their iCloud settings; the app should offer it in Settings › Library and
   call `CKModifyRecordZonesOperation` to delete the zone.
2. **No privacy notice on the site** for Vercel's logs and the lab's login.
   Short, on the network page, before any form goes live.
3. **Processor agreements** with Vercel and Supabase are their standard
   terms; record the versions accepted here when customers exist.
4. **The Watch's copy** should say that the system's dictation is Apple's
   and may use Apple's servers under the user's setting.
