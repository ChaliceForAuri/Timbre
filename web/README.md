# web/

The Spoke website, the University, and (soon) Backstage — one SvelteKit app.
Design and phases: `docs/design/backstage.md`; constraints: GDR-0006/0007.

```bash
pnpm install
pnpm dev        # http://localhost:5173
pnpm run check  # svelte-check
pnpm run build  # production build (adapter-vercel)
```

The Node toolchain stays inside this directory. University content in
`src/lib/university/` is extracted verbatim from
`docs/learning/spoke-university.html`; new modules are written in mdsvex.

Deploy: Vercel project with root directory `web/`. Every PR gets a preview
deployment.
