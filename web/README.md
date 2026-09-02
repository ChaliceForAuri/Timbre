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

## Environment

Three variables, set by hand in Vercel (Project → Settings → Environment
Variables) and in a local `.env` for development. See `.env.example`.

| Variable | What it is |
|---|---|
| `PUBLIC_SUPABASE_URL` | Project URL from Supabase → Settings → API |
| `PUBLIC_SUPABASE_ANON_KEY` | The anon/public key. Public by design — it ships in the browser, and RLS is what protects data, not this key |
| `BACKSTAGE_ALLOWLIST` | Comma-separated emails allowed into Backstage. **Unset means nobody**, deliberately |

The Supabase→Vercel integration is deliberately **not** used: it assumes one
Vercel project per Supabase project and gets confused otherwise, and setting
three variables by hand is auditable in a way that a sync you have to trust
is not.

`SUPABASE_SERVICE_ROLE_KEY` is not needed yet. It arrives with eval
publishing, which writes to RLS-locked tables. When it does, it is
server-only and must never carry the `PUBLIC_` prefix — that prefix is what
sends a value to the browser.

### Supabase auth configuration

Magic links fail silently unless their destination is allowlisted.
Supabase → Authentication → URL Configuration:

- **Site URL:** `https://timbre.hugopretorius.dev`
- **Redirect URLs:** `https://timbre.hugopretorius.dev/auth/callback` and
  `http://localhost:5173/auth/callback`

### Database

Schema lives in `supabase/migrations/` and is applied by Supabase's GitHub
integration on merge to `main` — "Deploy to production" on, "Automatic
branching" off, because branching compute sits outside the org spend cap.
Never write SQL in the dashboard editor; see `supabase/README.md`.
