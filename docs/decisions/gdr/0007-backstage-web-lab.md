# 0007 — Backstage: a web lab fed by dev-side artifacts

- **Status:** Accepted
- **Date:** 2026-08-19

## Context

The project needs a place to visualize and exercise its modules, browse eval
runs, hold the growing University, record feedback, and eventually manage
customers and payments. It is also deliberately a curriculum: the maintainer
is using this project to become an AI engineer, and evals, tracing, and
observability tooling are the skills being built.

The product's truth lives in Swift on macOS. FoundationModels and
SpeechAnalyzer cannot run on a server, and reimplementing the pure modules in
TypeScript so a browser could run them would create a second implementation
guaranteed to drift — the lab would then test fiction, the same failure the
synthetic corpus had (ADR-0004) one layer up.

## Decision

Backstage is a web application in `web/` — SvelteKit + shadcn-svelte on
Vercel, Supabase for auth and data, Langfuse for LLM traces — in the same
monorepo, under the same PR review process. The website and Backstage are one
app: public marketing routes and the public University, with the lab gated
behind Supabase auth.

Constraints that hold regardless of how the design evolves:

- **Data flows one way: dev side → lab.** Eval publishes, traces, and
  dictation exports originate from the developer's machines and CI, never
  from users' apps (GDR-0006).
- **Product logic is never reimplemented in the web stack.** Live module
  testing goes through a local daemon (`spoke-eval --serve`) exposing the
  real Swift code; without the daemon, Backstage shows recorded runs.
- **The Node toolchain stays inside `web/`.** Nothing outside it gains a JS
  dependency; the Swift side never gains a web dependency (the Langfuse SDK
  lives in Backstage, which forwards).
- **Web CI runs on ubuntu runners**, path-filtered to `web/**` and
  `supabase/**`, so web changes never cost 10×-billed macOS minutes and app
  changes never wait on npm installs.
- **Secrets live in Vercel env and GitHub Secrets only.**

The full design — routes, schema, phases — is `docs/design/backstage.md`,
which may evolve without superseding this record.

## Consequences

- Two stacks, one repo, one review process. The University finally gets
  navigation and room to grow, and ships first because it has an audience.
- Redundancy between the Supabase eval views and Langfuse is deliberate:
  build-it-yourself once, industry-tool once. That is the curriculum.
- The lab degrades gracefully: recorded truth everywhere, live playgrounds
  only where a Mac with the daemon is present — the same on-device property
  the product has.
- Supabase/Vercel/Langfuse are accepted vendor surface; all three have
  credible exits (Postgres, adapter swap, self-hosting).

## Alternatives considered

- **TypeScript ports of the pure modules for in-browser playgrounds:**
  rejected — divergence is certain, and half the modules can't be ported at
  all.
- **A native macOS companion app for the lab:** rejected — it abandons the
  web-stack learning goals, and a lab wants URLs, sharing, and deploy-per-PR.
- **Static site only (no Supabase):** rejected — it can't hold eval history,
  feedback, or a CRM, all of which are the point.
