## What changed, and why

<!-- The why matters more than the what; the diff already shows the what. -->

## How it was verified

<!-- Not "it builds". What did you observe that proves the change works?
     This project has repeatedly had changes that compiled, looked correct,
     and did nothing — a missing entitlement, a single-use analyzer, a prompt
     edit that passed one run and failed five. -->

- [ ] `swift test --package-path packages/TimbreKit`
- [ ] `xcrun swift-format lint --strict --recursive packages apps/Timbre/Sources`
- [ ] Ran the app and used the affected path

## Checks

- [ ] **Decision record** added if this constrains future work
      (ADR = constrains a file, GDR = constrains the product), or N/A
- [ ] **Polisher touched?** `timbre-eval --repeat 5` output before and after is
      pasted below. A single run is not a measurement.
- [ ] **Fixing a bug about reuse?** The test reuses the thing. A test that
      exercises it once passes against this class of bug.
- [ ] **New `@unchecked Sendable`?** The comment proves the invariant.
- [ ] No secrets, credentials, or signing identities added to the repo.

<!-- Polisher measurements, if applicable:

     before:  X/N cases   Y/M runs
     after:   X/N cases   Y/M runs
-->
