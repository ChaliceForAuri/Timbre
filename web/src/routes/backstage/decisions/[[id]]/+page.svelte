<script lang="ts">
	import { goto } from '$app/navigation';
	import { Badge } from '$lib/components/ui/badge';
	import { Button } from '$lib/components/ui/button';
	import * as Dialog from '$lib/components/ui/dialog';
	import * as ToggleGroup from '$lib/components/ui/toggle-group';
	import { records, type DecisionRecord, type Kind } from '$lib/decisions';
	import { reader } from '$lib/decisions/reader.svelte';
	import ChevronLeft from '@lucide/svelte/icons/chevron-left';
	import ChevronRight from '@lucide/svelte/icons/chevron-right';
	import Pause from '@lucide/svelte/icons/pause';
	import Play from '@lucide/svelte/icons/play';
	import SkipBack from '@lucide/svelte/icons/skip-back';
	import SkipForward from '@lucide/svelte/icons/skip-forward';
	import Square from '@lucide/svelte/icons/square';

	let { data } = $props();

	let kind: 'all' | Kind = $state('all');
	const visible = $derived(kind === 'all' ? records : records.filter((r) => r.kind === kind));
	const months = $derived(groupByMonth(visible));

	const counts = {
		adr: records.filter((r) => r.kind === 'ADR').length,
		gdr: records.filter((r) => r.kind === 'GDR').length,
		proposed: records.filter((r) => r.statusKind === 'proposed').length,
		superseded: records.filter((r) => r.statusKind === 'superseded').length
	};

	const open = $derived(data.open);
	const openIndex = $derived(open ? records.findIndex((r) => r.id === open.id) : -1);
	const newer = $derived(openIndex > 0 ? records[openIndex - 1] : undefined);
	const older = $derived(openIndex >= 0 && openIndex + 1 < records.length ? records[openIndex + 1] : undefined);

	const dayFormat = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short' });
	const monthFormat = new Intl.DateTimeFormat('en-GB', { month: 'long', year: 'numeric' });
	// Noon, so a date-only string never slips a day in a western timezone.
	const at = (iso: string) => new Date(`${iso}T12:00:00`);

	function groupByMonth(list: DecisionRecord[]) {
		const groups: { label: string; items: DecisionRecord[] }[] = [];
		for (const record of list) {
			const label = monthFormat.format(at(record.date));
			const last = groups.at(-1);
			if (last && last.label === label) last.items.push(record);
			else groups.push({ label, items: [record] });
		}
		return groups;
	}

	function close() {
		goto('/backstage/decisions', { noScroll: true, keepFocus: true });
	}

	const reading = $derived(reader.status !== 'idle' ? reader.current : undefined);

	// The dialog's only focusable elements are in its footer, so the focus
	// trap would open every record scrolled to its end. Focus the scroll
	// container instead: the record opens at its title and arrow keys scroll.
	let content = $state<HTMLElement | null>(null);
</script>

<svelte:head>
	<title>Decisions — Timbre Backstage</title>
	<meta name="robots" content="noindex" />
</svelte:head>

{#snippet marks(record: DecisionRecord)}
	<span
		class="rounded px-1.5 py-0.5 font-mono text-[10px] font-semibold text-[oklch(0.2_0.005_80)]"
		style="background: var(--retro-{record.kind === 'ADR' ? 'blue' : 'orange'})"
	>
		{record.kind}
	</span>
	<span class="font-mono">{record.id}</span>
	<span class="text-muted-foreground">{dayFormat.format(at(record.date))}</span>
	{#if record.statusKind === 'proposed'}
		<Badge variant="outline" class="border-amber-500/60 text-amber-700 dark:text-amber-400">Proposed</Badge>
	{:else if record.statusKind === 'superseded'}
		<Badge variant="destructive">
			Superseded{record.supersededBy ? ` by ${record.supersededBy}` : ''}
		</Badge>
	{:else if record.statusNote}
		<span class="text-muted-foreground">{record.statusNote}</span>
	{/if}
	{#each record.supersedes as id (id)}
		<span class="rounded-full border px-2 py-0.5">supersedes {id}</span>
	{/each}
	{#each record.relations as relation (relation.label)}
		<span class="text-muted-foreground rounded-full border px-2 py-0.5" title={relation.summary}>
			{relation.label.toLowerCase()} {relation.refs.join(', ') || relation.summary}
		</span>
	{/each}
{/snippet}

<div class="flex flex-wrap items-end justify-between gap-4">
	<div>
		<p class="eyebrow text-retro-yellow">Decisions</p>
		<h1 class="mt-2 text-4xl sm:text-5xl">What we decided.</h1>
		<p class="text-muted-foreground mt-3">
			What we decided, newest first. {counts.adr} ADRs · {counts.gdr} GDRs{counts.proposed
				? ` · ${counts.proposed} proposed`
				: ''}{counts.superseded ? ` · ${counts.superseded} superseded` : ''}.
		</p>
	</div>

	<div class="flex flex-wrap items-center gap-2">
		<ToggleGroup.Root
			type="single"
			variant="outline"
			value={kind}
			onValueChange={(value) => (kind = (value || 'all') as typeof kind)}
		>
			<ToggleGroup.Item value="all" class="px-3">All</ToggleGroup.Item>
			<ToggleGroup.Item value="ADR" class="px-3">ADR</ToggleGroup.Item>
			<ToggleGroup.Item value="GDR" class="px-3">GDR</ToggleGroup.Item>
		</ToggleGroup.Root>

		{#if reader.supported}
			<Button variant="outline" onclick={() => reader.play(visible)} disabled={visible.length === 0}>
				<Play class="size-4" /> Listen
			</Button>
		{/if}
	</div>
</div>

{#if reading}
	<div
		class="bg-card/95 sticky top-16 z-10 mt-6 flex items-center gap-2 rounded-xl border px-3 py-2 shadow-sm backdrop-blur-md"
	>
		<span class="bg-retro-green size-2 shrink-0 animate-pulse rounded-full"></span>
		<p class="min-w-0 flex-1 truncate text-sm">
			<span class="text-muted-foreground font-mono text-xs">{reading.id}</span>
			{reading.title}
			<span class="text-muted-foreground text-xs">· {reader.index + 1} of {reader.queue.length}</span>
		</p>
		<Button variant="ghost" size="icon" onclick={() => reader.previous()} aria-label="Previous record">
			<SkipBack class="size-4" />
		</Button>
		{#if reader.status === 'playing'}
			<Button variant="ghost" size="icon" onclick={() => reader.pause()} aria-label="Pause">
				<Pause class="size-4" />
			</Button>
		{:else}
			<Button variant="ghost" size="icon" onclick={() => reader.resume()} aria-label="Resume">
				<Play class="size-4" />
			</Button>
		{/if}
		<Button variant="ghost" size="icon" onclick={() => reader.next()} aria-label="Next record">
			<SkipForward class="size-4" />
		</Button>
		<Button variant="ghost" size="icon" onclick={() => reader.stop()} aria-label="Stop">
			<Square class="size-4" />
		</Button>
	</div>
{/if}

<div class="mt-10">
	{#each months as group (group.label)}
		<p class="eyebrow text-muted-foreground mb-4">{group.label}</p>
		<ol class="border-border/70 relative mb-10 ml-1.5 border-l pl-6">
			{#each group.items as record (record.id)}
				{@const superseded = record.statusKind === 'superseded'}
				{@const beingRead = reading?.id === record.id}
				<li class="relative mb-4">
					<span
						class="absolute top-7 -left-[29px] size-2 rounded-full"
						style="background: {beingRead ? 'var(--retro-green)' : `var(--retro-${record.kind === 'ADR' ? 'blue' : 'orange'})`}"
					></span>
					<a
						href="/backstage/decisions/{record.id}"
						data-sveltekit-noscroll
						class="bg-card ring-foreground/8 hover:ring-foreground/25 block rounded-2xl p-5 ring-1 transition-shadow
							{superseded ? 'opacity-60 ring-dashed hover:opacity-100' : ''}
							{beingRead ? 'ring-retro-green ring-2' : ''}"
					>
						<div class="flex flex-wrap items-center gap-2 text-xs">
							{@render marks(record)}
						</div>
						<h3 class="mt-3 text-2xl {superseded ? 'text-muted-foreground' : ''}">{record.title}</h3>
						<p class="text-muted-foreground mt-2 line-clamp-3 text-sm leading-relaxed">{record.excerpt}</p>
					</a>
				</li>
			{/each}
		</ol>
	{/each}
</div>

<Dialog.Root
	open={open !== null}
	onOpenChange={(isOpen) => {
		if (!isOpen) close();
	}}
>
	{#if open}
		<Dialog.Content
			bind:ref={content}
			tabindex={-1}
			class="max-h-[88vh] overflow-y-auto outline-none sm:max-w-3xl"
			onOpenAutoFocus={(event) => {
				event.preventDefault();
				content?.focus();
			}}
		>
			<Dialog.Header class="gap-3">
				<div class="flex flex-wrap items-center gap-2 pr-6 text-xs">
					{@render marks(open)}
				</div>
				<Dialog.Title class="display text-3xl leading-tight">{open.title}</Dialog.Title>
				<Dialog.Description class="font-mono text-xs">{open.path}</Dialog.Description>
			</Dialog.Header>

			<div class="record-prose mt-2">{@html open.html}</div>

			<Dialog.Footer class="mt-6 gap-2 border-t pt-4 sm:justify-between">
				<div class="flex gap-2">
					{#if newer}
						<Button variant="ghost" size="sm" href="/backstage/decisions/{newer.id}" data-sveltekit-noscroll>
							<ChevronLeft class="size-4" /> {newer.id}
						</Button>
					{/if}
					{#if older}
						<Button variant="ghost" size="sm" href="/backstage/decisions/{older.id}" data-sveltekit-noscroll>
							{older.id} <ChevronRight class="size-4" />
						</Button>
					{/if}
				</div>
				{#if reader.supported}
					<Button variant="outline" size="sm" onclick={() => reader.play([open])}>
						<Play class="size-4" /> Listen to this one
					</Button>
				{/if}
			</Dialog.Footer>
		</Dialog.Content>
	{/if}
</Dialog.Root>
