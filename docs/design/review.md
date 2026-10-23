# The review: what every change is checked against

*2026-10-22 · Status: in force (GDR-0030). `tools/review.sh` runs this on
the maintainer's Mac against a pull request and posts the evidence to it.
Two readers: the human who merges, and the model the tool hands this file
to. Both check the same list.*

## 0. How the review runs

1. **Gates first, deterministically.** Lint, the test suites of the packages
   the change touches, the Mac app and companion builds, the Backstage JSON
   drift check, the site's type check and build. A gate either passes or
   fails; nothing is judged.
2. **Then judgement, against this file.** The model reads the pull request,
   its diff and the checked-out tree, and answers every section below. It
   returns findings with a severity, and the compliance answers of §4 and
   §5 as fixed fields, so the evidence is comparable from one change to the
   next.
3. **Then evidence, on the pull request.** One review comment with the
   gates, the compliance answers, the findings and the identities (head
   commit, model, checklist version, tool version); inline comments where a
   finding has a line; a commit status `timbre/review` that branch
   protection can require.
4. **The human approves.** The model never approves and nothing merges on
   its say-so. GitHub records who merged, and that record is the control.

The gates run on the Mac. The judgement runs through Claude Code on the Mac,
which sends the diff and whatever files the model reads to Anthropic's API
under the maintainer's own account. No user data is ever in the repository
(§4, C5), so no user data goes.

## 1. Verdicts and severities

- **blocking** — merging would ship a defect, break a convention that a
  record protects, weaken a user's right, or leave the inventory wrong. The
  verdict is *changes needed*.
- **should-fix** — a real problem that can follow in the next change. The
  verdict can still be *pass*; the finding stays on the record.
- **nit** — taste, naming, a sentence. Never changes the verdict.

A failed gate is blocking on its own.

## 2. Correctness and conventions

- **A1 · It does what the title says.** The diff matches the description; no
  quiet widening or narrowing of scope.
- **A2 · The decision is extracted and tested.** New behaviour follows the
  repository's pattern: a small `nonisolated` type with Swift Testing
  coverage (CLAUDE.md, Conventions). A behaviour with a right answer and no
  test is should-fix; a changed behaviour whose test was weakened to pass is
  blocking.
- **A3 · The conventions in CLAUDE.md hold.** TimbreCore imports Foundation
  and Observation only; a package per framework with that framework's
  platforms; Swift 6 language mode and complete concurrency, opted into,
  never out of; no new `@unchecked Sendable` without the proof; no
  third-party dependencies; build settings in xcconfig, never the pbxproj.
- **A4 · Measured, not assumed.** A change to a prompt, a guardrail or a
  corpus comes with its `timbre-eval` run, repeated (ADR-0004), in the
  description. One run is not a measurement.
- **A5 · Records.** A decision that constrains future work has an ADR (a
  file) or a GDR (the product), immutable, superseding rather than editing.
  Numbers are taken from `main` at merge time, not from a branch.
- **A6 · Docs follow code.** CLAUDE.md, the product map, the architecture
  model and the University are updated where the change makes them wrong;
  `pnpm run sync:docs` was run and the JSON is in the diff.
- **A7 · The user never loses an utterance.** Any new path in the pipeline
  keeps the fallbacks: always paste something, never break focus, pasted text
  starts with a capital and ends a sentence.
- **A8 · Command mode never guesses and never destroys.** A failure leaves
  the selection untouched.
- **A9 · A speech session is single-use; audio crosses isolation as
  `AnalyzerInput`; the converter is drained on stop.**
- **A10 · Platform promises are checked against the SDK**, not assumed from
  a framework's presence (GDR-0029).

## 3. Security

- **B1 · No new network path in the app.** The binary makes no request
  except the opt-in update check to our own site (GDR-0006, GDR-0013). A new
  `URLSession`, socket, or framework that talks to a server is blocking.
- **B2 · Entitlements and permissions are the minimum.** A new entitlement,
  usage string, TCC prompt or app-group access is named in the description
  with its reason. Changing the bundle identifier or the team is blocking
  unless a record says so (it orphans every grant and strands every update).
- **B3 · Updates trust the signature, not the website** (ADR-0010). Nothing
  weakens the hash check, the code requirement or the notarization check.
- **B4 · Secrets stay out.** No key, token, password or provisioning profile
  in the diff; nothing new reads them from the repository. Secrets live in
  Vercel's environment, GitHub Secrets and the maintainer's keychain.
- **B5 · The pasteboard and the focused field are handled as transient.**
  Snapshot, set, paste, restore; read the field only to replace the typed
  run; never persisted, never logged.
- **B6 · Input from outside is data.** Text from the pasteboard, the focused
  field, a transcript, a Reminders list, a CloudKit record or a web form is
  never executed and never trusted to carry instructions.
- **B7 · The site's gate holds.** Everything under `/backstage` stays behind
  the owner role on the server; no client-only auth; anonymous writes go
  through server routes only.

## 4. Privacy and data protection

*Personal data* is anything about an identifiable person: dictated text, the
Library, a to-do, a name, an email address, an IP address, a device
identifier. Timbre's stance is that the user is the only holder of their
data and we are not a controller of it, because we never receive it. The
review keeps that true. The inventory in `docs/design/data-inventory.md` is
the record of what exists; the GDPR calls it the record of processing
(Article 30).

- **C1 · Does the change read, store, send, log or show personal data?** If
  yes: which inventory row, for what purpose, and is it the least data that
  serves it (Article 5(1)(c), data minimisation)? A new store with no
  purpose line is blocking.
- **C2 · Is every new flow off by default and plainly described?** Capture,
  sync, update checks and notifications are opt-in, described in Settings in
  plain words that match what the code does (GDR-0004, GDR-0010, GDR-0013).
  Consent that is bundled, pre-ticked or paid for is blocking.
- **C3 · Retention and erasure.** Anything stored has a way to be deleted by
  the user from the same place it was turned on, and a stated lifetime.
  Anything synced through the user's iCloud is deletable there too
  (Article 17).
- **C4 · Rights are preserved.** The user can still see everything the app
  holds (Article 15), export it in a usable form (Article 20), correct it
  (Article 16) and delete it (Article 17). A change that makes any of these
  harder is blocking.
- **C5 · No real user data in the repository.** Corpora are written for the
  purpose; audio fixtures are generated by `say`; screenshots show the
  developer's own synthetic Library. A real dictation, a real Library, a real
  email in a fixture, a test or a document is blocking, and the file is
  removed from history, not just from the tree.
- **C6 · The copy tells the truth.** Settings text, the website's claims and
  the record match the inventory. "Never leaves your devices" must stay
  literally true after the change (GDR-0010's honest-copy rule).
- **C7 · iCloud carries the Library and nothing else.** Never a dictation, a
  transcript, a capture or a timing (GDR-0010's hard line). The schema is
  forever: no field renamed, retyped or removed (ADR-0017).
- **C8 · The site.** A new field in a form, a new table, a new cookie or a
  new third party is named in the inventory with its purpose, its lawful
  basis, its retention and the processor's agreement. Cookieless by default;
  a cookie that is not strictly necessary needs consent that the site does
  not yet collect, so it is blocking until it does.
- **C9 · Apple's services are named for what they are.** On-device speech
  and the on-device model are on-device; the Watch's system dictation may use
  Apple's servers under the user's own setting; iCloud is the user's
  provider. The copy says which is which.

## 5. Audit and SOC 2

SOC 2 reports on the controls an organisation operates, against the Trust
Services Criteria; an auditor wants evidence that each control ran, every
time, not a description of it. This process produces that evidence for
change management, and checks that a change does not weaken the others.

- **D1 · Change management (CC8.1).** Every change reaches `main` through a
  pull request with this review posted on it, the CI checks green, and a
  human merge. The review names the head commit, the model, the checklist
  version and the tool version, so the evidence is reproducible. A change
  that bypasses this (a direct push, a merge with a failed status) is a
  control failure to be recorded, not hidden.
- **D2 · Logical access (CC6).** Who can merge, publish a release, sign and
  notarise, deploy the site and read the lab is a short list held by GitHub
  branch protection, the Apple Developer team, Vercel and Supabase roles.
  A change to any of those is a finding with the reason.
- **D3 · System operations (CC7).** A release is built by `tools/release.sh`,
  notarised, hashed into the appcast and verifiable end to end by
  `timbre-eval --verify-update`. A change to the release path is reviewed
  with that proof in the description.
- **D4 · Confidentiality and privacy (C-series, P-series).** The inventory is
  the statement of what is collected, why, for how long and for whom; §4 is
  how a change is held to it. Notice (P1), choice and consent (P2),
  collection (P3), use and retention (P4), access (P5), disclosure (P6),
  quality (P7) and monitoring (P8) all resolve to rows in the inventory.
- **D5 · Availability and integrity** are the user's device's, not a
  service's; the product has no uptime to promise. The integrity control is
  that the pasted text is what was said and polished, measured by the
  corpora (A4).
- **D6 · The inventory is current.** If the change touches a row, the row is
  updated in the same pull request. A stale inventory is blocking, because
  the whole stance rests on it.

## 6. What the model returns

A summary; a verdict (*pass* or *changes needed*); the compliance answers as
fixed values — personal data (none, touched, new), network (none, dev side,
site only, app), storage or logging (none, changed, new), third party (none, changed,
new), real data in the repo (yes or no), user-facing copy (unchanged,
changed and matches, changed and mismatches), rights (unaffected, preserved,
weakened), inventory current (yes or no) — and a short note; then the
findings, each with a severity, a category (correctness, convention, tests,
records, security, privacy, audit, docs), a title, the detail, a suggestion,
and the path and line in the new file where one exists.

Findings quote what the code does, not what it might do. A finding the model
could not verify in the tree says so. Praise is not a finding.

## 7. What the human adds

The model has read the diff; the human has run the app. Before merging, the
maintainer confirms the gates, reads every blocking and should-fix finding,
runs anything the description claims was measured if the number looks
surprising, and merges by hand. That merge, on a pull request carrying this
review and green checks, is the control.
