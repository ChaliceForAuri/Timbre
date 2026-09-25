// Records what timbre-eval measured, so Backstage shows numbers with a git
// SHA and a date next to them rather than a claim.
//
// Runs the polisher corpus and the command corpus five times each (the
// model is stochastic by default and deterministic by decoding; five repeats
// is the discipline ADR-0004 asks for), parses the harness output, and
// writes src/lib/evals/measured.json. Needs a Mac with the on-device model,
// so CI never runs it and the drift check leaves the file alone.
//
// Usage: pnpm run measure            (runs both corpora, ~3 minutes)
//        pnpm run measure -- --from <log>   (parse a saved run instead)

import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const pkg = resolve(here, '../../packages/TimbreKit');
const out = resolve(here, '../src/lib/evals/measured.json');
const REPEATS = 5;

function run(args) {
	return execFileSync('swift', ['run', '-c', 'release', 'timbre-eval', ...args], {
		cwd: pkg,
		encoding: 'utf8',
		stdio: ['ignore', 'pipe', 'inherit'],
		maxBuffer: 64 * 1024 * 1024
	});
}

const fromIndex = process.argv.indexOf('--from');
let log;
if (fromIndex !== -1) {
	log = readFileSync(process.argv[fromIndex + 1], 'utf8');
} else {
	const polisher = run(['Fixtures/corpus.json', '--repeat', String(REPEATS)]);
	const commands = run(['--commands', 'Fixtures/commands.json', '--repeat', String(REPEATS)]);
	log = `=== polisher ===\n${polisher}\n=== commands ===\n${commands}`;
}

const sha = execFileSync('git', ['rev-parse', '--short', 'HEAD'], { cwd: pkg, encoding: 'utf8' }).trim();

function section(name) {
	const start = log.indexOf(`=== ${name} ===`);
	if (start === -1) throw new Error(`no "${name}" section in the log`);
	const rest = log.slice(start);
	const next = rest.indexOf('\n=== ', 1);
	return next === -1 ? rest : rest.slice(0, next);
}

function totals(text) {
	const cases = text.match(/cases passing every run: (\d+)\/(\d+)/);
	const runs = text.match(/individual runs passing: (\d+)\/(\d+)/);
	if (!cases || !runs) throw new Error('summary lines missing');
	return {
		casesPassed: Number(cases[1]),
		cases: Number(cases[2]),
		runsPassed: Number(runs[1]),
		runs: Number(runs[2])
	};
}

/** "✓ fix-typos  [fix]  5/5  · 431 ms  · first words 352 ms" → one row per case. */
function perCase(text) {
	const rows = [];
	for (const line of text.split('\n')) {
		const m = line.match(/^([✓✗]) (\S+)(?:\s+\[(\w+)\])?\s+(\d+)\/(\d+)(?:\s+·\s+(\d+) ms)?(?:\s+·\s+first words (\d+) ms)?/);
		if (!m) continue;
		rows.push({
			id: m[2],
			verb: m[3] ?? null,
			passes: Number(m[4]),
			runs: Number(m[5]),
			ms: m[6] ? Number(m[6]) : null,
			firstWordsMs: m[7] ? Number(m[7]) : null
		});
	}
	return rows;
}

const polisherText = section('polisher');
const commandsText = section('commands');
const measured = {
	sha,
	date: new Date().toISOString().slice(0, 10),
	repeats: REPEATS,
	polisher: { ...totals(polisherText), perCase: perCase(polisherText) },
	commands: { ...totals(commandsText), perCase: perCase(commandsText) }
};

writeFileSync(out, JSON.stringify(measured, null, '\t') + '\n');
console.log(
	`${sha}: polisher ${measured.polisher.casesPassed}/${measured.polisher.cases}, commands ${measured.commands.casesPassed}/${measured.commands.cases} → src/lib/evals/measured.json`
);
