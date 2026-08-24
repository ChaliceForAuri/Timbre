<script lang="ts">
	import { page } from '$app/state';
	import { Separator } from '$lib/components/ui/separator';

	let { children, data } = $props();

	const sections = [
		{ href: '/backstage', label: 'Overview', exact: true },
		{ href: '/backstage/university', label: 'University' },
		{ href: '/backstage/evals', label: 'Evals', soon: true },
		{ href: '/backstage/feedback', label: 'Feedback', soon: true }
	];

	const isActive = (href: string, exact = false) =>
		exact ? page.url.pathname === href : page.url.pathname.startsWith(href);
</script>

<div class="mx-auto max-w-7xl px-6 py-6">
	<header class="mb-6 flex flex-wrap items-center gap-4">
		<a href="/" class="font-serif text-lg">Timbre</a>
		<span class="text-muted-foreground/50">/</span>
		<span class="text-sm font-medium">Backstage</span>

		<nav class="ml-4 flex flex-wrap gap-1 text-sm">
			{#each sections as section (section.href)}
				{#if section.soon}
					<span
						class="text-muted-foreground/50 cursor-not-allowed rounded-md px-3 py-1.5"
						title="Not built yet"
					>
						{section.label}
					</span>
				{:else}
					<a
						href={section.href}
						class="rounded-md px-3 py-1.5 transition-colors {isActive(section.href, section.exact)
							? 'bg-secondary text-secondary-foreground font-medium'
							: 'text-muted-foreground hover:text-foreground'}"
					>
						{section.label}
					</a>
				{/if}
			{/each}
		</nav>

		<form method="POST" action="/logout" class="ml-auto flex items-center gap-3">
			<span class="text-muted-foreground hidden text-xs sm:inline">{data.user?.email}</span>
			<button type="submit" class="text-muted-foreground hover:text-foreground text-xs underline">
				Sign out
			</button>
		</form>
	</header>

	<Separator class="mb-8" />

	{@render children()}
</div>
