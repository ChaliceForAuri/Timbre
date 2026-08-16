# Spoke website

Placeholder. The site starts when the app ships
([roadmap item 5](../CLAUDE.md)): a single page — what it is, the privacy
story, a download link, release notes.

Ground rules when this becomes real:

- The entire toolchain lives under `web/`. Nothing at the repo root may
  depend on Node or any web tooling.
- CI for the site is path-filtered to `web/**` — a copy change here must
  never trigger an Xcode build.
- The privacy claims on the site are backed by
  [GDR-0001](../docs/decisions/gdr/0001-local-only-free-no-account.md);
  keep them in sync.
