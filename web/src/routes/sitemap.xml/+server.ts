import { site } from '$lib/site';
import { modules } from '$lib/university';

export const prerender = true;

export function GET(): Response {
	const paths = ['/', '/download', ...modules.map((m) => `/university/${m.slug}`)];
	const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${paths.map((p) => `  <url><loc>${site.origin}${p}</loc></url>`).join('\n')}
</urlset>`;
	return new Response(body, {
		headers: { 'Content-Type': 'application/xml' }
	});
}
