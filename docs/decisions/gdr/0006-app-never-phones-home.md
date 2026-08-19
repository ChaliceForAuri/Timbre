# 0006 — The app never phones home; privacy is never a paid tier

- **Status:** Accepted
- **Date:** 2026-08-19

## Context

Backstage (GDR-0007) creates, for the first time, a server side to Spoke —
somewhere analytics *could* go. The question was asked directly: analytics on
for all users, with paying customers able to turn it off. Is that a good
idea?

Two separate claims were in tension:

1. [GDR-0001](0001-local-only-free-no-account.md) promises everything runs
   on-device. "This app makes zero network requests" is a **falsifiable**
   claim — anyone with Little Snitch can check it, and its checkability is
   what makes it worth anything. It is also the competitive wedge: for
   lawyers, clinicians, and anyone under NDA, cloud dictation is not a lesser
   option but a forbidden one. Spoke's entire commercial position is being
   the tool that provably never talks.
2. A commercial product wants to know its users. CRMs and analytics are how.

## Decision

**The app makes no network requests. No tier, no toggle, no exception.**
Specifically ruled out, permanently unless superseded:

- Telemetry, analytics, or crash reporting from the app, on any plan
- Licence checks, activations, trials, or any payment logic in the app
- **Charging to disable data collection.** Privacy as a paid feature inverts
  the product's one promise; in the only category where privacy *is* the
  product, "pay or be tracked" reads as extortion — and "consent or pay" is
  legally contested under GDPR besides. If analytics existed at all, the
  answer could not be to sell their absence.

What the business runs on instead:

- **Website analytics, server-side and cookieless** — page views on the
  site are the site's data, not the app's, and collecting them without
  cookies or identifiers requires no consent theatre
- **CRM from transactions** — downloads, purchases, support threads, and
  feedback people chose to send from a browser
- **Dev-side artifacts** — eval runs, traces, and dictation samples exported
  from the developer's own machines (GDR-0004's opt-in capture)

A "Send Feedback" affordance in the app may open a URL in the user's
browser: the browser makes that request, visibly, at the user's click. The
app binary itself performs no network I/O.

## Consequences

- The marketing claim stays absolute and survives inspection. This is the
  moat; this GDR is the fence around it.
- Product decisions must live without usage data. Feedback is solicited
  (issues, the site form, dictated reports) rather than surveilled.
- Sparkle-style auto-update would violate this record as written. When
  distribution needs updates, that is a supersession discussion — the
  likely shape being "check only on explicit user action," decided then.
- Revenue must come from charging for the product, not for privacy.

## Alternatives considered

- **Opt-in telemetry (free) rather than opt-out (paid):** still rejected.
  Even opt-in telemetry means the binary contains networking code, and
  "never" is a stronger, simpler, checkable claim than "only if you said
  yes."
- **Anonymous/aggregated analytics:** rejected as above — the wedge is not
  "we anonymize well," it is "we never connect."
