# web/

The Timbre website, the University, and (soon) Backstage — one SvelteKit app.
Design and phases: `docs/design/backstage.md`; constraints: GDR-0006/0007.

```bash
pnpm install
pnpm dev        # http://localhost:5173
pnpm run check  # svelte-check
pnpm run build  # production build (adapter-vercel)
```

The Node toolchain stays inside this directory. University content in
`src/lib/university/` is extracted verbatim from
`docs/learning/timbre-university.html`; new modules are written in mdsvex.

Deploy: Vercel project with root directory `web/`. Every PR gets a preview
deployment.

## Deployments

Only `main` deploys. `vercel.json`'s `ignoreCommand` skips every non-production
build, so pull requests no longer spin up preview deployments.

The exit codes are inverted from intuition and worth stating: Vercel treats
**exit 0 as "skip this build"** and **exit 1 as "go ahead"**. The command
therefore exits 1 on production and 0 everywhere else.

Preview deployments were genuinely useful for reviewing UI changes by
clicking rather than imagining. They are off because they added two checks to
every pull request — including Swift-only ones that cannot affect the site —
and the signal was not worth the noise. Deleting the file restores them.

Correctness is still gated: `Web check + build` runs `svelte-check` and a full
production build on every pull request, and it is a required check on `main`.
A site change that would fail to build cannot merge.

## Environment

Three variables, set by hand in Vercel (Project -> Settings -> Environment
Variables) and in a local `.env` for development. See `.env.example`.

| Variable | Secret? | What it is |
|---|---|---|
| `PUBLIC_SUPABASE_URL` | No | The project's API endpoint. Served in every page; there is nothing to hide |
| `PUBLIC_SUPABASE_ANON_KEY` | No, by design | Identifies the project and the `anon` role. It ships in the browser and grants nothing on its own — **RLS is the security boundary, not this key** |
| `BACKSTAGE_ALLOWLIST` | Not a credential, but private | Emails allowed into Backstage. Knowing it grants nothing (you still need the inbox), but it is personal data and stays server-side. **Unset means nobody**, deliberately |
| `SUPABASE_SERVICE_ROLE_KEY` | **Yes, absolutely** | Not needed yet. Bypasses RLS entirely — full read and write on every table. Never prefixed `PUBLIC_`, never committed, never logged |

In Vercel, set the first three as **Config** and the service role key (when it
arrives) as **Secret**. Vercel's Secret type is write-only — you can never read
the value back — which is right for a key you only rotate and wrong for the
allowlist, because an allowlist is a list you will edit. Losing the ability to
read it means every future change is retyped from memory.

The `PUBLIC_` prefix is not decoration: SvelteKit ships those values to the
browser and keeps everything else on the server. Prefixing the service role
key would publish full database access to every visitor.

The Supabase->Vercel integration is deliberately **not** used: it assumes one
Vercel project per Supabase project and gets confused otherwise, and setting
these by hand is auditable in a way that a sync you have to trust is not.

### Supabase auth configuration

Magic links fail silently unless their destination is allowlisted.
Supabase -> Authentication -> URL Configuration:

- **Site URL:** `https://timbre.hugopretorius.dev`
- **Redirect URLs:** `https://timbre.hugopretorius.dev/auth/callback` and
  `http://localhost:5173/auth/callback`

### Database

Schema lives in `supabase/migrations/`, applied by Supabase's GitHub
integration on merge to `main` — "Deploy to production" on, "Automatic
branching" off, because branching compute sits outside the org spend cap.
Never write SQL in the dashboard editor; see `supabase/README.md`.
