<script lang="ts">
	import { Badge } from '$lib/components/ui/badge';
	import { Button } from '$lib/components/ui/button';
	import * as Tabs from '$lib/components/ui/tabs';
	import { launchDocs } from '$lib/launch';
	import { plans } from '$lib/plans';
	import Copy from '@lucide/svelte/icons/copy';
	import Check from '@lucide/svelte/icons/check';
	import { page } from '$app/state';

	/// The announcement, the listing, the demo script and the shot list —
	/// each a markdown file in docs/launch, each one Copy button away from
	/// the place it is going. Editing happens in the repo, like everything.
	const launch = plans.find((p) => p.slug === 'launch-week');
	const announcement = launch?.items.filter((i) => i.section === 'Announcement') ?? [];

	const initial = page.url.hash.slice(1) || launchDocs[0]?.slug;
	let copied = $state<string | null>(null);

	async function copy(slug: string, text: string) {
		try {
			await navigator.clipboard.writeText(text);
			copied = slug;
			setTimeout(() => (copied = null), 1600);
		} catch {
			copied = null;
		}
	}
	const statusColor = (status: string) =>
		status.startsWith('draft') ? 'yellow' : status.startsWith('to ') ? 'orange' : 'green';
</script>

<svelte:head>
	<title>Launch — Timbre Backstage</title>
	<meta name="robots" content="noindex" />
</svelte:head>

<p class="eyebrow text-retro-blue">Launch</p>
<h1 class="mt-2 text-4xl sm:text-5xl">Telling the story.</h1>
<p class="text-muted-foreground mt-3 max-w-[62ch]">
	Everything that goes out with the release, written to be copied. Each document is a file in
	<code class="font-mono text-xs">docs/launch</code>; Hugo edits and approves before anything is posted.
</p>

{#if announcement.length}
	<div class="bg-card ring-foreground/8 mt-8 rounded-2xl p-5 ring-1">
		<p class="eyebrow text-muted-foreground">Announcement checklist · from the launch-week plan</p>
		<ul class="mt-3 grid gap-2 text-sm sm:grid-cols-2">
			{#each announcement as item (item.text)}
				<li class="flex gap-2.5">
					<span class="mt-0.5 flex size-4 shrink-0 items-center justify-center rounded-[4px] border-2 {item.done ? 'bg-retro-green border-retro-green' : 'border-border'}">
						{#if item.done}<Check class="size-3 text-[oklch(0.2_0.005_80)]" />{/if}
					</span>
					<span class={item.done ? 'text-muted-foreground' : ''}>{item.text}</span>
				</li>
			{/each}
		</ul>
	</div>
{/if}

<Tabs.Root value={initial} class="mt-8">
	<Tabs.List class="flex-wrap">
		{#each launchDocs as doc (doc.slug)}
			<Tabs.Trigger value={doc.slug}>{doc.title}</Tabs.Trigger>
		{/each}
	</Tabs.List>

	{#each launchDocs as doc (doc.slug)}
		<Tabs.Content value={doc.slug} class="mt-6">
			<article id={doc.slug} class="bg-card ring-foreground/8 scroll-mt-24 rounded-2xl p-6 ring-1 sm:p-8">
				<div class="flex flex-wrap items-center gap-3">
					<Badge variant="secondary" class="font-mono text-[10px] uppercase">{doc.kind}</Badge>
					<span class="inline-flex items-center gap-1.5 text-xs">
						<span class="size-2 rounded-full" style="background: var(--retro-{statusColor(doc.status)})"></span>
						{doc.status}
					</span>
					<span class="text-muted-foreground ml-auto font-mono text-[11px]">{doc.path}</span>
				</div>
				<h2 class="mt-4 text-3xl">{doc.title}</h2>
				{#if doc.intro}
					<p class="text-muted-foreground mt-2 max-w-[65ch] text-sm">{doc.intro}</p>
				{/if}
				{#if doc.copy}
					<div class="mt-5 flex items-center gap-3">
						<Button size="sm" onclick={() => copy(doc.slug, doc.copy ?? '')}>
							{#if copied === doc.slug}
								<Check class="size-4" /> Copied
							{:else}
								<Copy class="size-4" /> Copy the text
							{/if}
						</Button>
						<span class="text-muted-foreground text-xs">{doc.copy.length} characters · the “Copy” section only</span>
					</div>
				{/if}
				<div class="record-prose plan-prose mt-6">{@html doc.html}</div>
			</article>
		</Tabs.Content>
	{/each}
</Tabs.Root>
