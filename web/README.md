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
