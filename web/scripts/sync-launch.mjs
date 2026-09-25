// Turns docs/launch/*.md — the announcement copy, the listing, the demo
// script — into src/lib/launch/launch.json for Backstage's Launch page,
// where each document can be read and copied. Same arrangement as the
// other sync scripts: markdown is the source of truth, JSON is committed,
// CI fails on drift.
//
// Usage: pnpm run sync:launch

import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';

const here = dirname(fileURLToPath(import.meta.url));
const root = process.env.LAUNCH_DIR ?? resolve(here, '../../docs/launch');
const out = process.env.LAUNCH_OUT ?? resolve(here, '../src/lib/launch/launch.json');

function parse(source, slug, path) {
	const lines = source.split('\n');
	const title = (lines[0] ?? '').replace(/^#\s*/, '').trim();

	// Front matter, our way: "- **Key:** value" bullets before the first section.
	const headerEnd = lines.findIndex((line, i) => i > 0 && line.startsWith('## '));
	const header = lines.slice(1, headerEnd === -1 ? lines.length : headerEnd);
	const fields = Object.fromEntries(
		header
			.map((line) => line.match(/^- \*\*([^:*]+):\*\*\s*(.*)$/))
			.filter(Boolean)
			.map((m) => [m[1].trim().toLowerCase(), m[2].trim()])
	);
	const intro = header
		.filter((line) => line.trim() && !/^- \*\*/.test(line))
		.join(' ')
		.trim();

	// The copyable text is everything inside a "## Copy" section, verbatim,
	// so what lands in the clipboard is the post and not the notes around it.
	const body = headerEnd === -1 ? '' : lines.slice(headerEnd).join('\n').trim();
	const copy = body.match(/^## Copy\s*\n([\s\S]*?)(?=^## |\s*$(?![\s\S]))/m)?.[1]?.trim() ?? null;

	marked.use({ gfm: true });
	return {
		slug,
		path,
		title,
		intro,
		kind: fields.kind ?? 'document',
		status: fields.status ?? 'draft',
		order: Number(fields.order ?? 99),
		copy,
		html: marked.parse(body)
	};
}

const docs = [];
for (const file of readdirSync(root).sort()) {
	const match = file.match(/^(.+)\.md$/);
	if (!match) continue;
	docs.push(parse(readFileSync(join(root, file), 'utf8'), match[1], `docs/launch/${file}`));
}
docs.sort((a, b) => a.order - b.order || a.slug.localeCompare(b.slug));

writeFileSync(out, JSON.stringify(docs, null, '\t') + '\n');
console.log(`${docs.length} launch documents → ${out.replace(resolve(here, '..') + '/', '')}`);
