# supabase/

Schema as code. Every change to the database is a migration in
`migrations/`, reviewed in a pull request like any other code, and applied by
Supabase's GitHub integration when that PR merges to `main`.

Nothing is applied by hand in the dashboard SQL editor. A hand-applied change
is invisible to review and drifts from this directory silently — the database
equivalent of a test suite that passes against fiction.

## Naming

`<UTC timestamp>_<what it does>.sql`, e.g. `20260824120000_eval_runs.sql`.
Supabase applies them in filename order, once each, forever. A migration that
has run on production is immutable: fix it forward with a new one.

## Row Level Security

**Every table enables RLS and grants nothing.** That is deliberate and it is
not an oversight to be corrected later.

The `anon` key is public by design — it ships in the browser, and anyone can
read it out of the page source. RLS is therefore the only thing standing
between a table and the internet. Backstage renders server-side using the
service role, which bypasses RLS entirely, so a locked table costs us nothing
and protects everything.

If a table ever does need direct client access, that is a decision worth a
record, not a policy added quietly.
