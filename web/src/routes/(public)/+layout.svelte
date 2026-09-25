<script lang="ts">
	import { page } from '$app/state';
	import { Button } from '$lib/components/ui/button';
	import Mark from '$lib/components/marketing/Mark.svelte';
	import Stripe from '$lib/components/marketing/Stripe.svelte';
	import ThemeToggle from '$lib/components/site/ThemeToggle.svelte';
	import { site } from '$lib/site';

	let { children } = $props();

	const links = [
		{ href: '/#three-keys', label: 'How it works' },
		{ href: '/#compare', label: 'Compare' },
		{ href: '/network', label: 'Network' }
	];
	const current = (href: string) => href.startsWith('/#') ? false : page.url.pathname.startsWith(href);
</script>

<div class="flex min-h-screen flex-col">
	<header class="bg-background/85 sticky top-0 z-30 backdrop-blur-md">
		<nav class="mx-auto flex h-16 max-w-6xl items-center gap-5 px-6">
			<a href="/" class="flex items-center gap-2.5" aria-label="Timbre home">
				<Mark size={30} />
				<span class="flex flex-col gap-[5px]">
					<span class="display text-[1.6rem] leading-none">Timbre</span>
					<Stripe height="3px" />
				</span>
			</a>

			<div class="ml-auto hidden items-center gap-6 text-sm sm:flex">
				{#each links as link (link.href)}
					<a
						href={link.href}
						class="hover:text-foreground transition-colors {current(link.href)
							? 'text-foreground'
							: 'text-muted-foreground'}"
					>
						{link.label}
					</a>
				{/each}
				<a href="/backstage" rel="nofollow" class="text-muted-foreground hover:text-foreground transition-colors">
					Backstage
				</a>
			</div>

			<div class="ml-auto flex items-center gap-1 sm:ml-0">
				<ThemeToggle />
				<Button href="/download" size="sm" class="ml-1">Download</Button>
			</div>
		</nav>
	</header>

	<main class="flex-1">
		{@render children()}
	</main>

	<footer class="mt-16">
		<Stripe height="6px" rounded={false} />
		<div class="mx-auto grid max-w-6xl gap-10 px-6 py-12 sm:grid-cols-[1.2fr_1fr_1fr]">
			<div>
				<div class="flex items-center gap-2.5">
					<Mark size={26} />
					<p class="display text-2xl">Timbre</p>
				</div>
				<p class="text-muted-foreground mt-3 max-w-[38ch] text-sm leading-relaxed">
					{site.tagline} Free for personal use, built in the open, and it never sends your voice
					or your text off this Mac.
				</p>
			</div>
			<div class="text-sm">
				<p class="eyebrow text-muted-foreground mb-3">Product</p>
				<ul class="space-y-2">
					<li><a href="/download" class="hover:underline">Download</a></li>
					<li><a href="/network" class="hover:underline">Every network request</a></li>
					<li><a href="/#compare" class="hover:underline">How it compares</a></li>
					<li><a href="/#questions" class="hover:underline">Questions</a></li>
				</ul>
			</div>
			<div class="text-sm">
				<p class="eyebrow text-muted-foreground mb-3">Open</p>
				<ul class="space-y-2">
					<li><a href={site.repo} class="hover:underline">Source on GitHub</a></li>
					<li><a href="{site.repo}/blob/main/CHANGELOG.md" class="hover:underline">Changelog</a></li>
					<li><a href="{site.repo}/issues" class="hover:underline">Report a problem</a></li>
					<li><a href="/backstage" rel="nofollow" class="hover:underline">Backstage</a></li>
				</ul>
			</div>
		</div>
		<p class="text-muted-foreground mx-auto max-w-6xl px-6 pb-10 font-mono text-[11px]">
			macOS 26 · Apple Silicon · Notarized by Apple · Requires Apple Intelligence for cleanup and commands
		</p>
	</footer>
</div>
