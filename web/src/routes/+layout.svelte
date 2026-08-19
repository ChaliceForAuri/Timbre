<script lang="ts">
	import '../app.css';
	import { page } from '$app/state';

	let { children } = $props();

	const nav = [
		{ href: '/', label: 'Spoke' },
		{ href: '/university', label: 'University' },
		{ href: '/download', label: 'Download' }
	];
</script>

<div class="min-h-screen flex flex-col">
	<header class="border-b border-line">
		<nav class="mx-auto flex max-w-5xl items-center gap-6 px-6 py-4">
			<a href="/" class="font-semibold tracking-tight">Spoke</a>
			<div class="flex gap-5 text-sm text-muted">
				{#each nav.slice(1) as item (item.href)}
					<a
						href={item.href}
						class="hover:text-ink"
						class:text-accent-ink={page.url.pathname.startsWith(item.href)}
					>
						{item.label}
					</a>
				{/each}
			</div>
			<span class="ml-auto text-xs text-muted">free · on-device · zero network requests</span>
		</nav>
	</header>

	<main class="flex-1">
		{@render children()}
	</main>

	<footer class="border-t border-line">
		<div class="mx-auto max-w-5xl px-6 py-6 text-xs text-muted">
			Spoke never sends your voice, your text, or anything else off this Mac. Not a promise in a
			privacy policy — a property of the binary.
		</div>
	</footer>
</div>
