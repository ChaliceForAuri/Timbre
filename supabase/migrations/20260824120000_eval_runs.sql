-- Eval history: what timbre-eval measured, and when.
--
-- Populated by `timbre-eval --publish` from a developer machine or CI, never
-- by anyone's app (GDR-0006). Backstage reads it server-side to chart pass
-- rate against git history.

create table if not exists public.eval_runs (
    id             uuid primary key default gen_random_uuid(),
    corpus         text        not null,
    git_sha        text        not null,
    -- Hash of the polisher instructions, so a prompt change is visible even
    -- when the commit touched other things too.
    prompt_hash    text        not null,
    repeats        integer     not null check (repeats > 0),
    cases_passed   integer     not null check (cases_passed >= 0),
    cases_total    integer     not null check (cases_total >= 0),
    runs_passed    integer     not null check (runs_passed >= 0),
    runs_total     integer     not null check (runs_total >= 0),
    -- Set once the same run has been mirrored into Langfuse (design §7).
    langfuse_run_id text,
    created_at     timestamptz not null default now()
);

create table if not exists public.eval_results (
    id        uuid primary key default gen_random_uuid(),
    run_id    uuid    not null references public.eval_runs (id) on delete cascade,
    case_id   text    not null,
    output    text    not null,
    -- The failure lines exactly as PolishChecks produced them.
    failures  jsonb   not null default '[]'::jsonb,
    passed    boolean not null
);

-- Charts read newest-first by corpus; drill-downs read by run.
create index if not exists eval_runs_corpus_created_idx
    on public.eval_runs (corpus, created_at desc);
create index if not exists eval_results_run_idx
    on public.eval_results (run_id);

-- Locked by default. No policies: only the service role, which bypasses RLS,
-- may touch these. The anon key is public and must never be able to read a
-- table simply because it exists. See supabase/README.md.
alter table public.eval_runs    enable row level security;
alter table public.eval_results enable row level security;
