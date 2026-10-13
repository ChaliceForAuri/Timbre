// Turns docs/design/*.md — the product map and the Backstage design — into
// src/lib/design/design.json for the Architecture room's written half. Same
// arrangement as the other sync scripts: markdown is the source of truth,
// the JSON is committed, CI fails on drift.
//
// Usage: pnpm run sync:design

import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';

const here = dirname(fileURLToPath(import.meta.url));
const root = process.env.DESIGN_DIR ?? resolve(here, '../../docs/design');
const out = process.env.DESIGN_OUT ?? resolve(here, '../src/lib/design/design.json');

marked.use({ gfm: true });
const docs = [];
for (const file of readdirSync(root).sort()) {
	const match = file.match(/^(.+)\.md$/);
	if (!match) continue;
	const source = readFileSync(join(root, file), 'utf8');
	const lines = source.split('\n');
	const title = (lines[0] ?? '').replace(/^#\s*/, '').trim();
	// The italic line under the title is the status line; the rest is the body.
	const body = lines.slice(1).join('\n').trim();
	const status = body.match(/^\*([^*]+)\*/)?.[1]?.replace(/\s+/g, ' ').trim() ?? '';
	docs.push({ slug: match[1], path: `docs/design/${file}`, title, status, html: marked.parse(body) });
}
writeFileSync(out, JSON.stringify(docs, null, '\t') + '\n');
console.log(`${docs.length} design documents → ${out.replace(resolve(here, '..') + '/', '')}`);
