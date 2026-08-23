import { site } from '$lib/site';

export const prerender = true;

export function GET(): Response {
	// University now lives behind auth, so it is deliberately absent:
	// a sitemap advertising pages that return a redirect is worse than
	// a short sitemap.
	const paths = ['/', '/download'];
	const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${paths.map((p) => `  <url><loc>${site.origin}${p}</loc></url>`).join('\n')}
</urlset>`;
	return new Response(body, {
		headers: { 'Content-Type': 'application/xml' }
	});
}
