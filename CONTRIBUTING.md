# Working on Timbre

Currently a one-person project, so this is mostly a contract with future-me.
It is written down because the failure modes below were all paid for once
already.

## The loop

```bash
git checkout -b <kind>/<short-description>     # never commit to main
# … work …
swift test --package-path packages/TimbreKit
xcrun swift-format lint --strict --recursive packages apps/Timbre/Sources
git push -u origin HEAD
gh pr create
```

CI must be green — and it is now *enforced* on `main`, not merely expected:
every pull request runs the TimbreKit tests, the app build, and the web
check. Both workflows run unfiltered, because a required check that a path
filter skips never reports, and the pull request then waits on it forever. Merge with **squash** — one commit per change keeps `main`
readable and bisectable, and lets branch commits be as messy as they need to
be.

`main` is protected. That is deliberate even with no other contributors: it
makes CI a gate rather than a suggestion, and it forces a diff to be read
before it lands.

### Review, when there is no reviewer

A solo pull request does not give you review. It gives you a CI gate, a diff
you have to look at, and somewhere for the reasoning to live. The missing
second pair of eyes comes from running `/code-review` on the branch before
merging. That is the substitute; skipping it means the PR is only a CI gate.

## What a pull request must answer

The template asks these. They exist because each one has already caught
something real:

**How did you verify it — not "did it build"?** Three times in one day, a
change compiled, read correctly, and did nothing: a missing hardened-runtime
entitlement, a single-use `SpeechAnalyzer`, a prompt edit that passed one run
and failed the next five. "It builds" and "it works" are different claims.

**Did the polisher change? Then measure it, five runs minimum.** The model is
stochastic. A prompt edit was once judged a success on one run and scored 0 of
5 when repeated; another was reverted as useless and turned out to have nearly
doubled the pass rate. Single runs actively mislead. See ADR-0004.

**Is the bug about reuse? Then the test must reuse.** `SpeechAnalyzer` is
single-use, so only the *second* dictation failed. Any test transcribing one
file passes against that bug. See ADR-0006.

**Does it need a decision record?** ADR if it constrains a file, GDR if it
constrains the product. When in doubt it is a GDR — those are the ones whose
reasoning is forgotten first. Records are immutable; supersede, never edit.

**New `@unchecked Sendable`?** Prove the invariant in a comment. There is one
in the codebase (`AudioTapProcessor`) and its comment explains exactly why it
is safe.

## Things that are not negotiable

- **No secrets in the repo.** Signing identity lives in the gitignored
  `apps/Timbre/Config/Local.xcconfig`. Notarization credentials belong in
  GitHub Secrets or the keychain, never a file.
- **No third-party dependencies.** Apple frameworks and toolchain tools only.
- **No network calls from the app.** GDR-0001 is the product. That includes
  analytics, crash reporting, update checks, and licence validation. A
  donation link that opens a browser is fine; the app itself stays silent.
- **Build settings live in xcconfig files**, never edited into the pbxproj.

## Releasing

1. Bump `MARKETING_VERSION` in `apps/Timbre/Config/Shared.xcconfig`
2. Move `CHANGELOG.md`'s Unreleased entries under the new version
3. Merge to `main`, then tag `v<version>` — the tag must match the xcconfig
4. Notarize and staple before distributing (needs a Developer ID Application
   certificate, not the development one)
