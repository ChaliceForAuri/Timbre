// Turns docs/plans/*.md into src/lib/plans/plans.json — the same arrangement
// as sync-decisions.mjs: markdown is the source of truth, the rendered
// output is committed, CI fails on drift.
//
// A plan is a markdown document with an H1 title, an optional intro
// paragraph, sections, and GitHub task lists. Ticked boxes are progress;
// the page shows a bar and the count. Editing the markdown is how a box
// gets ticked, which keeps the plan reviewable in the repo like anything else.
//
// Usage: pnpm run sync:plans

import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';

const here = dirname(fileURLToPath(import.meta.url));
const root = process.env.PLANS_DIR ?? resolve(here, '../../docs/plans');
const out = process.env.PLANS_OUT ?? resolve(here, '../src/lib/plans/plans.json');

function parse(source, slug, path) {
	const lines = source.split('\n');
	const title = (lines[0] ?? '').replace(/^#\s*/, '').trim();
	const body = lines.slice(1).join('\n').trim();

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

	const done = (body.match(/^\s*- \[x\]/gim) ?? []).length;
	const open = (body.match(/^\s*- \[ \]/gm) ?? []).length;

	// The body starts at the first section; the header (fields and intro) is
	// shown by the page itself.
	const sections = headerEnd === -1 ? '' : lines.slice(headerEnd).join('\n').trim();
	marked.use({ gfm: true });
	const html = marked.parse(sections);

	return {
		slug,
		path,
		title,
		intro,
		date: fields.date ?? '',
		order: Number(fields.order ?? 99),
		done,
		open,
		html
	};
}

const plans = [];
for (const file of readdirSync(root).sort()) {
	const match = file.match(/^(.+)\.md$/);
	if (!match) continue;
	plans.push(parse(readFileSync(join(root, file), 'utf8'), match[1], `docs/plans/${file}`));
}
plans.sort((a, b) => a.order - b.order || a.slug.localeCompare(b.slug));

writeFileSync(out, JSON.stringify(plans, null, '\t') + '\n');
console.log(`${plans.length} plans → ${out.replace(resolve(here, '..') + '/', '')}`);
