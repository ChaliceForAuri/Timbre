# Backstage — design

*2026-08-19 · Status: agreed direction, phased build. Constraining decisions
live in [GDR-0006](../decisions/gdr/0006-app-never-phones-home.md) and
[GDR-0007](../decisions/gdr/0007-backstage-web-lab.md); this document is the
working design and may evolve.*

Backstage is Spoke's laboratory: a web app where every module of the product
can be exercised, measured, and learned from — and, behind the same door, the
website, the University, the feedback record, and eventually the customer
list. It is also, explicitly, Hugo's AI-engineering curriculum: every layer is
chosen to teach something the CV needs (evals, observability, tracing,
RLS-backed multi-tenant data, modern full-stack).

## 1. The one hard rule

Everything below hangs off a single boundary:

```
┌──────────────────────────┐        artifacts, one direction only        ┌─────────────────────────┐
│  Spoke.app (macOS)       │  ─────────────────────────────────────────▶ │  Backstage (web)        │
│  zero network I/O, ever  │   eval JSON · dictation exports (opt-in)    │  SvelteKit + Supabase   │
│  GDR-0001, GDR-0006      │   GitHub issues · Stripe webhooks           │  Vercel + Langfuse      │
└──────────────────────────┘                                             └─────────────────────────┘
```

**The app never phones home. Nothing in this design changes that.** Data
reaches Backstage only from the *development* side (spoke-eval, CI, imports
Hugo performs) or from *web* interactions (site visits, purchases, feedback
forms in a browser). "Analytics on for all users" is off the table, and so is
"pay to turn analytics off" — the reasoning is in GDR-0006, summarized in §9.

## 2. Stack and what each piece teaches

| Piece | Role | The lesson in it |
|---|---|---|
| SvelteKit 2 / Svelte 5 | Site + Backstage app | Modern reactive UI (runes), SSR, route groups, form actions |
| shadcn-svelte + Tailwind | UI system | Composition-over-library design systems |
| Supabase | Auth, Postgres, RLS | Real database modelling, row-level security, auth flows |
| Vercel | Hosting, preview deploys | CI/CD where every PR gets a URL |
| Langfuse | LLM observability | Traces, generations, scores, datasets — the eval vocabulary employers ask about |
| mdsvex | University content | Markdown-as-components, content pipelines |
| `spoke-eval --serve` | Local lab daemon | Service design; keeping one source of truth for logic |

Node toolchain lives entirely inside `web/` (pnpm, Node 22). Nothing outside
`web/` gains a JS dependency.

## 3. Monorepo layout

```
web/
  src/routes/
    (public)/                 marketing site: /, /download, /pricing
    (public)/university/      the University, sidebar navigation, mdsvex
    backstage/                gated: Supabase auth + owner allowlist
      lab/[module]/           module playgrounds (§5)
      evals/                  runs, cases, diffs over time (§6)
      feedback/               the feedback record (§8)
      customers/              CRM, Stripe-fed (§10, later)
    api/                      ingest endpoints (eval publish, feedback mirror)
  src/lib/components/ui/      shadcn-svelte
  src/lib/server/             supabase admin client, langfuse client
supabase/
  migrations/                 SQL, versioned, reviewed like code
```

Same repo, same review process: branch → PR → CI → squash. A `web.yml`
workflow runs lint, `svelte-check`, and vitest on **ubuntu** runners (1×
minutes, unlike the 10× macOS jobs) with `paths: [web/**, supabase/**]`.
Vercel builds preview deployments per PR — review a UI change by clicking,
not by imagining.

## 4. Auth and gating

The website and Backstage are one app. Public routes need nothing; everything
under `/backstage` requires a Supabase session **and** an owner-role profile
(single allowlisted email at first — signups exist for customers later, not
for the lab). Gate lives in `backstage/+layout.server.ts`; there is no
client-only auth anywhere. The University starts public: it is the
learning-in-public artifact and the best marketing the site will have.

## 5. The module sandbox

The trap to avoid: reimplementing SpokeKit's logic in TypeScript so the
browser can run it. Two implementations of `SentenceTerminator` *will*
diverge, and then the lab tests fiction — the same sin as the synthetic
corpus, one layer up. Also impossible for the model modules: FoundationModels
and SpeechAnalyzer only exist on macOS; a Vercel function cannot run them.

So the lab keeps one source of truth: **`spoke-eval --serve`**, a local HTTP
daemon mode on the Mac (port 4242) exposing the real Swift modules:

```
GET  /health                      → { version, model_available }
POST /polish                      → real TextPolisher (+ trace to Langfuse)
POST /terminate                   → SentenceTerminator
POST /spoken-commands             → SpokenCommands
POST /guardrail                   → PolishGuardrail verdict
POST /transcribe   (audio file)   → real Transcriber
POST /eval-run     (corpus id)    → full spoke-eval run, results persisted
```

Backstage lab pages probe `localhost:4242`. Daemon up → live playground
against the real code (type a transcript, see polish/terminate/commands run,
with per-stage latency). Daemon down → pages degrade to the recorded runs in
Supabase. The daemon answers with `Access-Control-Allow-Private-Network:
true` so a Vercel-hosted page may call localhost (Chrome PNA rules).

This is the design's best trick: the browser UI is universal, but the truth
always executes on-device — the same property the product itself has.

## 6. Evals in Backstage

`spoke-eval` gains `--publish`: after a run, POST the results (corpus id, git
SHA, prompt hash, repeats, per-case outcomes) to `/api/evals` with a service
token. Backstage renders:

- **Runs over time** — pass rate against git history: "did this prompt change
  help" becomes a chart, not a memory
- **Case drill-down** — every output variant a case produced across repeats,
  failures highlighted
- **Diff view** — two runs side by side, regressions in red

The 30%→47%→87%→98% arc from ADR-0004/0005 becomes the first recorded data.

## 7. Langfuse, in parallel and on purpose

Langfuse gets the *trace-level* view that Supabase tables don't model well,
and it is deliberately redundant with §6 — the redundancy is the curriculum:
build it yourself once (Supabase), use the industry tool once (Langfuse), and
you can explain both in an interview.

- Every `/polish` through the daemon emits a **trace**: input transcript →
  prompt assembly (app context, vocabulary) → **generation** (model output,
  latency) → guardrail verdict → terminator output.
- Each corpus becomes a Langfuse **dataset**; each `--publish` run a dataset
  **run** with per-case **scores** (pass/fail per check).
- Ingestion happens in `web/src/lib/server/langfuse.ts` via the JS SDK — the
  daemon posts to Backstage, Backstage forwards. One place holds the key;
  the Swift side never needs a Langfuse dependency.
- **Never from users' machines.** Traces originate from Hugo's dev loop and
  CI only. Same boundary as everything else.

University module 14 teaches the concepts against this live wiring.

## 8. The feedback record

Feedback becomes a first-class record type, with GitHub issues as the
canonical store (they already do threading, labels, state, and `gh` access):

1. Something annoys you → dictate it (Spoke eating its own dog food) into
   `gh issue create --label feedback`
2. A sync route mirrors `feedback`-labeled issues into the `feedback` table
   so Backstage can browse, tag, and link them to eval cases and releases
3. A public `/feedback` form on the site (browser, not app) writes the same
   table for future users
4. Feedback that changes direction still graduates to an ADR/GDR — issues
   record *what happened*, decision records record *what we decided*

First entry is already filed: the start-of-speech clipping found this morning.

## 9. Analytics and the "pay to disable" question

Asked and answered as a constraint, not a preference (full reasoning in
GDR-0006):

- **In-app analytics for all users** would make the app phone home. GDR-0001's
  "zero network requests" is a *falsifiable* claim — Little Snitch users will
  check — and it is the entire competitive wedge. Breaking it converts Spoke
  from "the one that never talks to the internet" into "another dictation app
  with telemetry."
- **Charging to turn analytics off** prices privacy as a feature. In the one
  product category where privacy *is* the product, that reads as extortion,
  and "consent or pay" is legally contested under GDPR besides. Rejected.
- **What exists instead:** server-side, cookieless page analytics on the
  website (a `page_views` table — you own the data, no consent banner
  needed); CRM populated by *transactions* (downloads, purchases, support
  threads — §10); and opt-in artifacts Hugo exports from his own machines.
- Monetization charges for **the product**, never for silence.

## 10. Customers and payments (deferred phase)

Stripe Checkout on the site; webhook → `customers` table (email, product,
license status). The honour-system commercial licence from the monetization
discussion: free personal use, paid commercial use, license key delivered by
email, **no in-app enforcement ever** — a licence check is a network call
(GDR-0001/0006). The CRM is Backstage's `customers` view over that table plus
feedback linkage: "this customer reported that issue" is one join.

## 11. Data model (v1)

```sql
profiles          (id → auth.users, email, role)         -- role: owner|customer
feedback          (id, source, body, app_context, github_issue, status, created_at)
eval_runs         (id, corpus, git_sha, prompt_hash, repeats,
                   cases_passed, cases_total, runs_passed, runs_total,
                   langfuse_run_id, created_at)
eval_results      (run_id, case_id, output, failures jsonb, passed)
dictation_samples (id, transcript, polished, app_context, recorded_at)  -- Hugo's opt-in exports only
page_views        (id, path, referrer, country, created_at)             -- no user id, no cookie
customers         (id, email, stripe_customer, product, status, created_at)
```

RLS: owner reads/writes everything; `page_views` and `feedback` accept
anonymous inserts through server routes only (service role); customers see
nothing (there is no customer-facing Backstage). Migrations are SQL files in
`supabase/migrations/`, reviewed in PRs like any other code.

## 12. University migration

The single 91 KB HTML becomes mdsvex pages under `(public)/university/` with
a shadcn sidebar: 13 existing modules → one route each, prose intact; the
original file stays in `docs/learning/` as the historical artifact.
`field-notes.md` **stays in the repo** — it's a dev-facing lab notebook, and
its immutability-by-append matters; University pages may quote it.

New modules the growth plan already implies:

- **13 · Evals in practice** — the ADR-0004 story: properties over exact
  match, stochasticity, `--repeat`, the 30%→98% arc
- **14 · LLM observability & Langfuse** — traces, generations, scores,
  datasets; wired to the live §7 integration
- **15 · The web stack, for someone who just learned Swift** — runes vs
  `@Observable`, RLS vs sandboxing, the same concepts wearing different names

## 13. Phases

| Phase | Delivers | Proof it works |
|---|---|---|
| 0 (done today) | This design, GDR-0006/0007, feedback issue #1 | merged PR |
| 1 | SvelteKit scaffold in `web/`, shadcn, University migrated with sidebar, Vercel deploy, `web.yml` CI | University readable at a real URL |
| 2 | Supabase project, auth, `/backstage` shell, eval publishing + runs browser | 87%→98% arc visible as a chart |
| 3 | Langfuse wiring + traces, University modules 13–14 | a polish trace inspectable end-to-end |
| 4 | `spoke-eval --serve` + live module playgrounds | type into the browser, real Swift answers |
| 5 | Feedback mirror + site feedback form | issue #1 visible in Backstage |
| 6 | Stripe, customers, downloads page | first real licence sold |

Each phase is one or more PRs; nothing lands unreviewed. Phase order is
deliberate: the University ships first because it's the piece with an
audience, and evals ship before playgrounds because recorded truth beats live
toys.

## 14. Risks, named

- **The lab outgrowing the product.** Backstage is infrastructure *for* Spoke;
  the roadmap's item 1 is still polisher quality. Time-box: if a phase
  doesn't serve shipping or learning, it waits.
- **Single maintainer, two stacks.** Mitigated by the same review process,
  and by the daemon pattern keeping all product logic in one language.
- **Vendor surface** (Supabase/Vercel/Langfuse). All three have exits
  (Postgres is Postgres, adapters swap, Langfuse self-hosts). Accepted for
  the learning value — using the real tools is the point.
- **Secrets sprawl.** Service keys live in Vercel env + GitHub Secrets only.
  The repo rule stands: nothing secret is ever committed.
