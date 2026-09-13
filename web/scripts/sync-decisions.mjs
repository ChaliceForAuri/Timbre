// Turns docs/decisions/{adr,gdr}/NNNN-*.md into src/lib/decisions/records.json.
//
// The markdown files stay the source of truth; this output is committed so
// the deploy never has to reach outside web/, and CI fails if it drifts
// (see .github/workflows/web.yml). Rendering happens here, once, so the
// running site carries no markdown code: each record ships as HTML for the
// dialog, plain text for the reader, and an excerpt for the timeline card.
//
// Usage: pnpm run sync:decisions

import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';

const here = dirname(fileURLToPath(import.meta.url));
// Overridable so the parser can be exercised against scratch records.
const root = process.env.DECISIONS_DIR ?? resolve(here, '../../docs/decisions');
const out = process.env.DECISIONS_OUT ?? resolve(here, '../src/lib/decisions/records.json');
const KINDS = { adr: 'ADR', gdr: 'GDR' };

/** A link target inside a record → the id of the record it points at, or null. */
function resolveRef(href, selfKind) {
	const inKind = href.match(/(?:^|\/)(adr|gdr)\/(\d{4})-[^/]*\.md(?:#.*)?$/);
	if (inKind) return `${KINDS[inKind[1]]}-${inKind[2]}`;
	const sibling = href.match(/^(\d{4})-[^/]*\.md(?:#.*)?$/);
	if (sibling) return `${selfKind}-${sibling[1]}`;
	return null;
}

/** Markdown → something a voice can read: no markup, tables as rows, code skipped. */
function plainText(md) {
	return md
		.replace(/```[\s\S]*?```/g, ' Code sample omitted. ')
		.replace(/^\|\s*:?-{2,}.*$/gm, '')
		.replace(/^\|(.+)\|\s*$/gm, (_, row) =>
			row
				.split('|')
				.map((cell) => cell.trim())
				.filter(Boolean)
				.join(', ') + '.'
		)
		.replace(/^#{1,6}\s+(.+?)\s*$/gm, '$1.')
		.replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
		.replace(/[*_`>]/g, '')
		.replace(/^\s*[-•]\s+/gm, '')
		.replace(/[ \t]+/g, ' ')
		.replace(/\n{2,}/g, '\n')
		.trim();
}

function truncate(text, max) {
	if (text.length <= max) return text;
	const cut = text.slice(0, max);
	return cut.slice(0, Math.max(cut.lastIndexOf(' '), max - 20)).trimEnd() + '…';
}

function refsIn(text, selfKind) {
	const refs = new Set();
	for (const [, href] of text.matchAll(/\[[^\]]*\]\(([^)]+)\)/g)) {
		const ref = resolveRef(href, selfKind);
		if (ref) refs.add(ref);
	}
	for (const [, kind, number] of text.matchAll(/\b(ADR|GDR)-(\d{4})\b/g)) refs.add(`${kind}-${number}`);
	return [...refs];
}

function parse(source, kind, number, slug, path) {
	const lines = source.split('\n');
	const titleLine = lines[0] ?? '';
	const title = titleLine.replace(/^#\s*\d{4}\s*—\s*/, '').trim();

	const bodyStart = lines.findIndex((line) => line.startsWith('## '));
	const header = lines.slice(1, bodyStart === -1 ? lines.length : bodyStart);
	const body = bodyStart === -1 ? '' : lines.slice(bodyStart).join('\n').trim();

	// Header bullets: "- **Label:** text", continuation lines indented.
	const bullets = [];
	for (const line of header) {
		if (/^- \*\*/.test(line)) bullets.push(line);
		else if (line.trim() && bullets.length) bullets[bullets.length - 1] += ' ' + line.trim();
	}
	const fields = bullets.map((bullet) => {
		const match = bullet.match(/^- \*\*([^:*]+):\*\*\s*(.*)$/);
		return match ? { label: match[1].trim(), text: match[2].trim() } : null;
	}).filter(Boolean);

	const status = fields.find((f) => f.label === 'Status')?.text ?? 'Accepted';
	const date = fields.find((f) => f.label === 'Date')?.text ?? '';
	const statusKind = /^superseded/i.test(status)
		? 'superseded'
		: /^proposed/i.test(status)
			? 'proposed'
			: 'accepted';
	const statusNote = status.match(/\(([^)]+)\)/)?.[1] ?? null;
	const supersededBy = statusKind === 'superseded' ? (refsIn(status, kind)[0] ?? null) : null;

	const relations = fields
		.filter((f) => f.label !== 'Status' && f.label !== 'Date')
		.map((f) => ({ label: f.label, summary: truncate(plainText(f.text), 80), refs: refsIn(f.text, kind) }));

	const context = body.match(/^## Context\s*\n([\s\S]*?)(?=^## |\s*$(?![\s\S]))/m)?.[1] ?? body;
	const firstParagraph = context.trim().split(/\n\s*\n/)[0] ?? '';
	const excerpt = truncate(plainText(firstParagraph), 360);

	let currentKind = kind;
	marked.use({
		gfm: true,
		walkTokens(token) {
			if (token.type === 'link') {
				const ref = resolveRef(token.href, currentKind);
				if (ref) token.href = `/backstage/decisions/${ref}`;
			}
		}
	});
	const html = marked.parse(body);

	const plain = plainText(`${status}.\n${body}`);

	return {
		id: `${kind}-${number}`,
		kind,
		number,
		slug,
		path,
		title,
		status,
		statusKind,
		statusNote,
		supersededBy,
		supersedes: [],
		date,
		relations,
		excerpt,
		plain,
		html
	};
}

const records = [];
for (const dir of Object.keys(KINDS)) {
	for (const file of readdirSync(join(root, dir)).sort()) {
		const match = file.match(/^(\d{4})-(.+)\.md$/);
		if (!match || match[1] === '0000') continue;
		const source = readFileSync(join(root, dir, file), 'utf8');
		records.push(parse(source, KINDS[dir], match[1], match[2], `docs/decisions/${dir}/${file}`));
	}
}

const byId = new Map(records.map((r) => [r.id, r]));
for (const record of records) {
	if (record.supersededBy && byId.has(record.supersededBy)) {
		byId.get(record.supersededBy).supersedes.push(record.id);
	}
}

records.sort((a, b) => b.date.localeCompare(a.date) || b.number.localeCompare(a.number) || a.kind.localeCompare(b.kind));

writeFileSync(out, JSON.stringify(records, null, '\t') + '\n');
console.log(`${records.length} records → ${out.replace(resolve(here, '..') + '/', '')}`);
