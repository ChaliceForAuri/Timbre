# 0013 — An update check, off by default, is the only network request Timbre can ever make

- **Status:** Proposed
- **Date:** 2026-09-18
- **Amends:** the "not an update check" line of
  [GDR-0006](0006-app-never-phones-home.md) and the landing page copy that
  quotes it. Everything else in GDR-0006 stands.

## Context

Timbre is distributed outside the App Store (ADR-0003 rules the sandbox out),
so nothing tells a user that a new version exists. Every release so far has
reached its three users by hand. A LinkedIn launch changes that: people who
install 0.3.0 will otherwise still be running 0.3.0 next spring, with every
bug it shipped.

GDR-0006 promised that the binary makes no network requests, and named the
update check specifically as one of the things it will not do. The landing
page repeats it as the claim a reader can falsify with Little Snitch. That
promise has been the product's identity, and the reason it is believed.

Tidy — the closest comparable product — ships automatic updates *and*
claims "no network calls, ever". Both cannot be true; an update feed is a
network call. That is the kind of gap Timbre's story exists to avoid.

## Decision

Timbre may check for updates, on these terms:

- **Off by default.** A fresh install makes no network requests at all, as
  before. The check exists as a menu item, *Check for Updates…*, which does
  one thing when you click it; and as a Settings toggle, *Check daily*, off
  until you turn it on.
- **One request, to our own site, carrying nothing.** `GET
  https://timbre.hugopretorius.dev/appcast.json` — a static file, no query
  string, no cookies, no identifiers, no telemetry, nothing about the Mac
  beyond what any HTTP request carries. That is the only network request the
  binary is capable of making, and the claim becomes: *Timbre makes no
  network requests unless you turn on update checks, and then the only one it
  ever makes is for a version file on our own site.* Still falsifiable in
  thirty seconds.
- **Installing is one click and verified.** The zip is downloaded from the
  same host, its code signature checked against our Team ID and its
  notarization ticket before anything is replaced, then the app swaps itself
  in /Applications and relaunches. A failed check leaves the installed app
  untouched.
- **No Sparkle.** It is a third-party dependency, and its default profile
  reporting is exactly the kind of request this record exists to forbid. The
  whole mechanism is URLSession, Security and FileManager.
- **Release notes travel with the check.** The appcast carries the notes, so
  "what changed" is answered in the app, not by a trip to GitHub.

## Consequences

- GDR-0006's spirit is intact: nothing identifies the user, nothing is sent
  about them, and the default install is as silent as it has always been. Its
  letter changes by one clause, and the landing page, the FAQ and the footer
  change with it the day this ships — not before.
- The one thing our host learns, when a user opts in, is that an IP address
  fetched a file. That is stated in Settings next to the toggle.
- `release.sh` gains the appcast: version, zip URL, SHA-256, and the notes.
  A release is not done until the appcast is published with it.
- A user who never opens Settings never updates. Accepted; it is the price
  of the default, and the menu item is one click away.

## Alternatives considered

- **No update check, ever:** rejected; it strands every user on the version
  they installed, which is worse for them than one opt-in request.
- **On by default with an opt-out:** rejected; "zero network requests"
  would become a sentence with a footnote, and the footnote is the product.
- **Sparkle:** rejected on dependency and default-behaviour grounds above.
- **App Store distribution:** rejected already; the sandbox blocks the
  synthetic paste (ADR-0003).
- **A "new version" notice on the website only:** kept — the download page
  says what is current — but it does not reach anyone who is not looking.
