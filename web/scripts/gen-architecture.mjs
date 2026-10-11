// Turns docs/architecture/*.c4 (the LikeC4 model of the whole product) into
// the web component Backstage's Architecture room renders. The output is a
// build artifact — a few megabytes of bundled diagram engine — so it is
// generated, gitignored, and rebuilt on every install (see "prepare" in
// package.json). The .c4 files are the source of truth, like every other
// room's markdown.
//
// Usage: pnpm run gen:architecture

import { execFileSync } from 'node:child_process';
import { existsSync, statSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const model = resolve(here, '../../docs/architecture');
const out = resolve(here, '../src/lib/architecture/likec4-views.js');

if (!existsSync(model)) {
	console.error(`no model at ${model}`);
	process.exit(1);
}
execFileSync('npx', ['likec4', 'codegen', 'webcomponent', '-w', 'c4', '-o', out, model], {
	cwd: resolve(here, '..'),
	stdio: ['ignore', 'ignore', 'inherit']
});
const kb = Math.round(statSync(out).size / 1024);
console.log(`C4 model → src/lib/architecture/likec4-views.js (${kb} kB)`);
