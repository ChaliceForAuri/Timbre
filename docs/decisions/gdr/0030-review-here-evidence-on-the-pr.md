# 0030 — Every change is reviewed here, and the review is evidence

- **Status:** Accepted
- **Date:** 2026-10-22
- **Builds on:** [GDR-0006](0006-app-never-phones-home.md) (what the app
  may never do), [GDR-0007](0007-backstage-web-lab.md) (one pull request
  process for the whole monorepo), [GDR-0013](0013-update-check-off-by-default.md) (the
  one request), [ADR-0004](../adr/0004-evaluation-harness-seam.md) (measure, do
  not assume), [ADR-0010](../adr/0010-self-update-without-sparkle.md) (trust the
  signature).

## Context

Hugo asked for two things at once. The review of every change should run on
his Mac, not through a hosted reviewer that needs tokens and sends the diff
to a service we do not control; and the product should be built so that
when an auditor arrives — SOC 2, a GDPR data-protection question, a
customer's security questionnaire — nothing has to be rebuilt to answer.

The two are one thing. An auditor does not want a description of a control;
they want evidence that it ran, every time. The pull request is already the
unit of change (GDR-0007), CI already runs the suites, and branch protection
already requires them. What is missing is a review that is the same every
time, written down, posted where the change lives, and a record of what
personal data exists at all, so a change can be held to it.

The product's promise makes the privacy half short: the user is the only
holder of their data, because we never receive it. That promise is worth
nothing unless every change is checked against it.

## Decision

**Every change is reviewed on the maintainer's Mac against a written
checklist, and the evidence is posted to the pull request.**

1. **The review runs here.** `tools/review.sh <pr>` checks out the pull
   request's head beside the evidence, runs the gates — lint, the suites of
   the packages the change touches, the Mac and companion builds, the
   Backstage JSON drift check, the site's check and build — and then has the
   model read the change against `docs/design/review.md` and
   `docs/design/data-inventory.md`. The model is Claude Code in headless
   mode on this Mac, under the maintainer's own account, with Read, Grep
   and Glob as its only tools, confined to the run directory and the tree,
   and no project instructions loaded; the maintainer's own settings and
   memory still apply, and the checklist is the instruction. No token in CI, no hosted reviewer, no secret anywhere but
   the maintainer's own logins.
2. **The evidence is on the pull request.** One review comment with the
   gates, the compliance answers as fixed fields, the findings, and the
   identities that make it reproducible: the head commit, the model, the
   checklist's hash, the tool's hash, who ran it and when. Inline comments
   where a finding has a line. A commit status `timbre/review` on the head,
   which branch protection requires alongside the CI checks.
3. **The checklist is the compliance stance.** `docs/design/review.md` holds
   correctness and conventions, security, privacy and data protection, and
   the audit criteria, each as a question with a severity. The inventory in
   `docs/design/data-inventory.md` is the record of processing (GDPR
   Article 30): what exists, where, why, for how long, how it is erased. A
   change that touches a row updates the row in the same pull request;
   a stale inventory is blocking.
4. **The model advises; the human approves.** The review never approves and
   nothing merges on its verdict. The maintainer reads it, runs what needs
   running, and merges by hand; GitHub's record of that merge, on a pull
   request carrying the review and green checks, is the change-management
   control.
5. **No real user data in the repository, ever.** Corpora are written for
   the purpose, audio is generated, screenshots are synthetic. The import of
   the maintainer's own captures is ignored by git. This is what lets the
   review's model see the diff at all.

## Consequences

- A fourth required status on `main`: `timbre/review`, beside the three required CI
  checks, set in GitHub by hand, once. The status alone is a claim any
  account with write access could post; the evidence is the review comment
  with its hashes and the local copy under `.review/`, and the status is
  what stops a merge without them.
- The judgement is not local inference. The diff and the files the model
  reads go to Anthropic's API under the maintainer's account; the record
  says so plainly, and decision 5 is what makes it acceptable. A future
  on-device reviewer would supersede this clause, not the rest.
- Each review costs minutes on the Mac and tokens on the maintainer's plan;
  the review comment records the cost. `--skip-gates` trusts CI for the
  gates and says so in the evidence.
- The checklist and the inventory are living design documents (they render
  in Backstage with the rest of `docs/design`); their hashes on each review
  are what tie a past verdict to the rules it was judged by.
- The inventory names its own gaps, from an in-app "delete from iCloud" to
  end-to-end encryption of the sync. They are the next items of the
  roadmap, not footnotes, and the list is kept there, not here.

## Alternatives considered

- **GitHub's hosted code review (Copilot).** Needs tokens and a plan, cannot
  be given this checklist, and sends the diff to a service with its own
  retention. Rejected.
- **A GitHub Actions job calling a model API.** Puts an API key in GitHub
  Secrets and sends every push out automatically, with no human in the
  loop deciding to review. Rejected: the maintainer should start a review
  the way they start a release.
- **Gates only, no model.** Keeps everything on the Mac but loses the
  reading that catches a weakened right, a stale inventory or a quiet
  network path. Rejected for now; the gates alone remain a valid
  `--skip-judgement` run in an emergency, recorded as such.
- **The on-device model as the reviewer.** Honest to the product's spirit,
  not yet able to read a two-thousand-line diff against a checklist. Noted
  for later.
