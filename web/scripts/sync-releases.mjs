// Turns CHANGELOG.md into src/lib/releases/releases.json: one entry per
// version, newest first, with each Keep-a-Changelog section rendered to
// HTML. The Unreleased section becomes the draft at the top, so Backstage
// shows what the next release already contains. Same arrangement as the
// other sync scripts: the markdown is the source of truth, the JSON is
// committed, CI fails on drift.
//
// Usage: pnpm run sync:releases

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';

const here = dirname(fileURLToPath(import.meta.url));
const changelog = process.env.CHANGELOG ?? resolve(here, '../../CHANGELOG.md');
const out = process.env.RELEASES_OUT ?? resolve(here, '../src/lib/releases/releases.json');
const REPO = 'https://github.com/ChaliceForAuri/Timbre';

const source = readFileSync(changelog, 'utf8');
marked.use({ gfm: true });

const releases = [];
let current = null;
let section = null;
const flush = () => {
	if (current && section) {
		current.sections.push({ name: section.name, html: marked.parse(section.lines.join('\n').trim()) });
	}
	section = null;
};

for (const line of source.split('\n')) {
	// Reference links at the bottom of the file are not part of any release.
	if (/^\[[^\]]+\]:\s+http/.test(line)) continue;

	const heading = line.match(/^## \[([^\]]+)\](?:\s+[—-]+\s+(\d{4}-\d{2}-\d{2}))?/);
	if (heading) {
		flush();
		const version = heading[1];
		current = {
			version,
			date: heading[2] ?? null,
			unreleased: version === 'Unreleased',
			url: version === 'Unreleased' ? `${REPO}/blob/main/CHANGELOG.md` : `${REPO}/releases/tag/v${version}`,
			intro: '',
			sections: []
		};
		releases.push(current);
		continue;
	}
	if (!current) continue;

	const sub = line.match(/^### (.+)$/);
	if (sub) {
		flush();
		section = { name: sub[1].trim(), lines: [] };
		continue;
	}
	if (section) section.lines.push(line);
	else if (line.trim()) current.intro += (current.intro ? ' ' : '') + line.trim();
}
flush();

for (const release of releases) {
	release.items = release.sections.reduce(
		(n, s) => n + (s.html.match(/<li>/g) ?? []).length,
		0
	);
}

writeFileSync(out, JSON.stringify(releases, null, '\t') + '\n');
console.log(`${releases.length} releases → ${out.replace(resolve(here, '..') + '/', '')}`);
