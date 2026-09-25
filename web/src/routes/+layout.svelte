<script lang="ts">
	import '../app.css';
	import { page } from '$app/state';
	import { site } from '$lib/site';

	let { children } = $props();

	const canonical = $derived(site.origin + page.url.pathname);
</script>

<svelte:head>
	<link rel="preconnect" href="https://fonts.googleapis.com" />
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
	<!-- Archivo carries a width axis: one family gives the condensed headline
	     cut and the regular text cut, so the page loads one face, not two. -->
	<link
		rel="stylesheet"
		href="https://fonts.googleapis.com/css2?family=Archivo:ital,wdth,wght@0,75..112,400..900;1,75..112,400..900&family=IBM+Plex+Mono:wght@400;500;600&display=swap"
	/>
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
