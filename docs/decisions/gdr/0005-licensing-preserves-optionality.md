# 0005 — Licensing starts closed to preserve optionality

- **Status:** Accepted
- **Date:** 2026-08-18

## Context

Spoke is intended to be free to use and may later be supported by donations.
The repository had no `LICENSE` file at all and had never been pushed
anywhere, so the question was still open — which is the only time it can be
answered cheaply.

Licensing is close to irreversible in one direction. Code published under a
permissive licence stays published under it: that commit can be forked,
rebranded, and sold, indefinitely, with no recourse. Future versions can be
relicensed, but the community keeps the last permissive commit. Restrictive
terms, by contrast, can be loosened at any time with a single commit.

A second point was clouding the decision: [GDR-0001](0001-local-only-free-no-account.md)
promises the product is free, local, and account-free. That is a promise about
**price and privacy**, not about source licensing. Free-to-use and
source-proprietary are compatible, and a public repository is not the same
thing as an open-source one.

## Decision

The repository is **private**, and `LICENSE` reserves all rights.

The permissive-versus-proprietary question is deferred until immediately
before the first public release, when the monetization model is actually
known rather than guessed at. Until then the terms stay closed, because closed
can become open and open cannot become closed.

Specifically: do **not** apply MIT, Apache-2.0, or any other permissive
licence to any commit before that decision is made deliberately.

## Consequences

- Every option remains available, at the cost of no community contributions in
  the meantime — which is worth nothing yet, since nobody can see the repo.
- Nothing in the product changes. Spoke is still free, still local, still
  account-free.
- Before going public, the decision needs real thought and probably a lawyer's
  eye. Candidate directions, none chosen here: permissive (Apache-2.0, with
  its patent grant) for maximum goodwill; source-available with commercial use
  reserved; or proprietary source with a free end-user licence, which is what
  most free Mac utilities actually are.
- A consequence for the *architecture*, not just the paperwork: monetization
  must not put payments, licence checks, or trial logic in the app. All of
  those need network access and would break GDR-0001 outright. A donation link
  that opens a browser keeps the app itself silent, which is the point.

## Alternatives considered

- **MIT or Apache-2.0 immediately:** rejected for now. It forecloses charging
  for anything later, and the goodwill it buys is worth little while the
  repository is private and the product unreleased.
- **No LICENSE file at all:** rejected. Absent terms the default is already
  "all rights reserved", but relying on a reader knowing that is worse than
  saying so, and it leaves no place to record the reasoning.
