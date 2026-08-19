import manifest from './manifest.json';

export type UniversityModule = {
	slug: string;
	number: string;
	title: string;
};

export const modules: UniversityModule[] = manifest;

// Extracted verbatim from the original Spoke University document
// (docs/learning/spoke-university.html) — one fragment per module. New
// modules are written in mdsvex instead; these stay faithful to the source.
const fragments = import.meta.glob('./*.html', {
	query: '?raw',
	import: 'default',
	eager: true
}) as Record<string, string>;

export function fragmentFor(slug: string): string | undefined {
	return fragments[`./${slug}.html`];
}
