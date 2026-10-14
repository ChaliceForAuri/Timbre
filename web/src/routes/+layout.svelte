<script lang="ts">
	import '../app.css';
	import { page } from '$app/state';
	import { site } from '$lib/site';

	let { children } = $props();

	const canonical = $derived(site.origin + page.url.pathname);
</script>

<svelte:head>
	<!-- Nunito, Nunito Sans and IBM Plex Mono, served from this site: a visit
	     makes no request to Google. static/fonts/fonts.css, OFL. -->
	<link rel="preload" href="/fonts/Nunito-400-800-latin.woff2" as="font" type="font/woff2" crossorigin="anonymous" />
	<link rel="preload" href="/fonts/NunitoSans-400-latin.woff2" as="font" type="font/woff2" crossorigin="anonymous" />
	<link rel="stylesheet" href="/fonts/fonts.css" />
	<link rel="canonical" href={canonical} />
	<meta property="og:url" content={canonical} />
	<meta property="og:site_name" content={site.name} />
	<meta property="og:type" content="website" />
	<meta property="og:image" content="{site.origin}/og.png" />
	<meta property="og:image:width" content="1200" />
	<meta property="og:image:height" content="630" />
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:image" content="{site.origin}/og.png" />
</svelte:head>

{@render children()}
