<script lang="ts">
	import { onMount } from 'svelte';
	import { Badge } from '$lib/components/ui/badge';
	import * as ToggleGroup from '$lib/components/ui/toggle-group';
	import * as Tabs from '$lib/components/ui/tabs';
	import { perspectives, type PerspectiveId } from '$lib/architecture';
	import { designDocs } from '$lib/design';
	import { theme } from '$lib/theme.svelte';
	import viewsScript from '$lib/architecture/likec4-views.js?url';

	/// The whole product as a C4 model, written in LikeC4 under
	/// docs/architecture and rendered by its web component: pan, zoom, click
	/// an element to drill into its own view. The perspectives are the
	/// views the model declares; the written half below is docs/design.
	let perspective = $state<PerspectiveId>('index');
	let ready = $state(false);

	const current = $derived(perspectives.find((p) => p.id === perspective) ?? perspectives[0]);

	onMount(() => {
		const script = document.createElement('script');
		script.src = viewsScript;
		script.onload = () => (ready = true);
		document.head.append(script);
		return () => script.remove();
	});
</script>

<svelte:head>
	<title>Architecture — Timbre Backstage</title>
	<meta name="robots" content="noindex" />
</svelte:head>

<div class="flex flex-wrap items-end justify-between gap-4">
	<div>
		<p class="eyebrow text-retro-blue">Architecture</p>
		<h1 class="mt-2 text-4xl sm:text-5xl">The whole product, from every side.</h1>
		<p class="text-muted-foreground mt-3 max-w-[62ch]">
			A C4 model of what is shipped, what is Apple's, what is planned and what is still an open
			decision. Written as text in <code class="font-mono text-xs">docs/architecture</code>, so it
			is reviewed like code; click any box to drill into it.
		</p>
	</div>
	<div class="flex flex-wrap gap-2 text-xs">
		<Badge variant="secondary">shipped</Badge>
		<Badge class="bg-retro-yellow text-[oklch(0.2_0.005_80)] hover:bg-retro-yellow">planned</Badge>
		<Badge class="bg-retro-red text-[oklch(0.99_0.002_80)] hover:bg-retro-red">open decision</Badge>
		<Badge variant="outline">Apple's</Badge>
	</div>
</div>

<div class="mt-8 flex flex-wrap items-center justify-between gap-3">
	<ToggleGroup.Root
		type="single"
		variant="outline"
		value={perspective}
		onValueChange={(v) => {
			if (v) perspective = v as PerspectiveId;
		}}
	>
		{#each perspectives as p (p.id)}
			<ToggleGroup.Item value={p.id} class="px-3">{p.label}</ToggleGroup.Item>
		{/each}
	</ToggleGroup.Root>
	<p class="text-muted-foreground text-sm">{current.blurb}</p>
</div>

<div class="bg-card ring-foreground/8 mt-4 h-[72vh] min-h-[480px] overflow-hidden rounded-2xl ring-1">
	{#if ready}
		<c4-view
			view-id={perspective}
			browser="true"
			color-scheme={theme.dark ? 'dark' : 'light'}
			style="display:block;width:100%;height:100%"
		></c4-view>
	{:else}
		<div class="text-muted-foreground flex h-full items-center justify-center text-sm">
			Loading the model…
		</div>
	{/if}
</div>

<p class="text-muted-foreground mt-3 font-mono text-[11px]">
	docs/architecture/specification.c4 · model.c4 · views.c4 — regenerated on every install by
	scripts/gen-architecture.mjs
</p>

{#if designDocs.length}
	<Tabs.Root value={designDocs[0].slug} class="mt-12">
		<Tabs.List>
			{#each designDocs as doc (doc.slug)}
				<Tabs.Trigger value={doc.slug}>{doc.title}</Tabs.Trigger>
			{/each}
		</Tabs.List>
		{#each designDocs as doc (doc.slug)}
			<Tabs.Content value={doc.slug} class="mt-6">
				<article class="bg-card ring-foreground/8 rounded-2xl p-6 ring-1 sm:p-8">
					<p class="text-muted-foreground font-mono text-[11px]">{doc.path}</p>
					<div class="record-prose mt-6 max-w-none [&_h1]:hidden">{@html doc.html}</div>
				</article>
			</Tabs.Content>
		{/each}
	</Tabs.Root>
{/if}
