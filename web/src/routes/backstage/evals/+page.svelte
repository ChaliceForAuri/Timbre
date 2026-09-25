<script lang="ts">
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { Badge } from '$lib/components/ui/badge';
	import * as Dialog from '$lib/components/ui/dialog';
	import * as Table from '$lib/components/ui/table';
	import * as Tabs from '$lib/components/ui/tabs';
	import * as ToggleGroup from '$lib/components/ui/toggle-group';
	import Stat from '$lib/components/backstage/Stat.svelte';
	import { evals, latest, type CommandCase, type PolisherCase } from '$lib/evals';

	/// The corpora, case by case, and what they measured last. A case is a
	/// transcript and its checks; the checks are properties, never exact
	/// strings (ADR-0004), so the table shows what must survive and what
	/// must go rather than one blessed answer.
	const verbColor: Record<string, string> = { fix: 'green', shorten: 'yellow', plain: 'blue', explain: 'violet' };
	let verb = $state<'all' | CommandCase['command']>('all');
	const commandCases = $derived(
		verb === 'all' ? evals.commands.cases : evals.commands.cases.filter((c) => c.command === verb)
	);

	const measuredById = new Map(
		[...latest.polisher.perCase, ...latest.commands.perCase].map((m) => [m.id, m])
	);
	const median = (values: number[]) => {
		const sorted = [...values].sort((a, b) => a - b);
		return sorted.length ? sorted[Math.floor(sorted.length / 2)] : 0;
	};
	const commandMedian = median(latest.commands.perCase.map((m) => m.ms ?? 0).filter(Boolean));

	// ?case=<id> opens a case, so the command palette and links can land on one.
	const openId = $derived(page.url.searchParams.get('case'));
	const open = $derived<PolisherCase | CommandCase | undefined>(
		openId
			? (evals.polisher.cases.find((c) => c.id === openId) ?? evals.commands.cases.find((c) => c.id === openId))
			: undefined
	);
	const isCommand = (c: PolisherCase | CommandCase): c is CommandCase => 'command' in c;
	const tab = $derived(open && isCommand(open) ? 'commands' : 'polisher');

	function show(id: string) {
		goto(`/backstage/evals?case=${id}`, { noScroll: true, keepFocus: true });
	}
	function close() {
		goto('/backstage/evals', { noScroll: true, keepFocus: true });
	}
</script>

<svelte:head>
	<title>Evals — Timbre Backstage</title>
	<meta name="robots" content="noindex" />
</svelte:head>

<p class="eyebrow text-retro-violet">Evals</p>
<h1 class="mt-2 text-4xl sm:text-5xl">Measured, not felt.</h1>
<p class="text-muted-foreground mt-3 max-w-[62ch]">
	Every prompt change is judged against these cases, five runs each. The numbers below are from the
	last recorded run on a Mac with the model; the cases are read from the fixtures in the repo.
</p>

<div class="mt-8 grid gap-4 sm:grid-cols-3">
	<Stat label="Polisher" value="{latest.polisher.casesPassed}/{latest.polisher.cases}" detail="{latest.polisher.runsPassed} of {latest.polisher.runs} runs · ×{latest.repeats}" color="green" />
	<Stat label="Commands" value="{latest.commands.casesPassed}/{latest.commands.cases}" detail="{latest.commands.runsPassed} of {latest.commands.runs} runs · median {commandMedian} ms" color="violet" />
	<Stat label="Recorded" value={latest.sha} detail="{latest.date} · pnpm run measure" color="orange" />
</div>

<Tabs.Root value={tab} class="mt-10">
	<Tabs.List>
		<Tabs.Trigger value="polisher">Polisher · {evals.polisher.cases.length}</Tabs.Trigger>
		<Tabs.Trigger value="commands">Commands · {evals.commands.cases.length}</Tabs.Trigger>
		<Tabs.Trigger value="how">How to run</Tabs.Trigger>
	</Tabs.List>

	<Tabs.Content value="polisher" class="mt-4">
		<p class="text-muted-foreground mb-3 font-mono text-xs">{evals.polisher.path} · one audio fixture per case</p>
		<div class="bg-card ring-foreground/8 overflow-hidden rounded-2xl ring-1">
			<Table.Root>
				<Table.Header>
					<Table.Row>
						<Table.Head class="eyebrow">Case</Table.Head>
						<Table.Head class="eyebrow">What it tests</Table.Head>
						<Table.Head class="eyebrow text-right">Must keep</Table.Head>
						<Table.Head class="eyebrow text-right">Must drop</Table.Head>
						<Table.Head class="eyebrow text-right">Last run</Table.Head>
					</Table.Row>
				</Table.Header>
				<Table.Body>
					{#each evals.polisher.cases as c (c.id)}
						{@const m = measuredById.get(c.id)}
						<Table.Row class="cursor-pointer" onclick={() => show(c.id)}>
							<Table.Cell class="font-mono text-xs">{c.id}</Table.Cell>
							<Table.Cell class="max-w-[40ch] truncate text-sm">{c.note}</Table.Cell>
							<Table.Cell class="text-right font-mono text-xs">{c.required.length}</Table.Cell>
							<Table.Cell class="text-right font-mono text-xs">{c.forbidden.length}</Table.Cell>
							<Table.Cell class="text-right font-mono text-xs">
								{#if m}
									<span class={m.passes === m.runs ? 'text-retro-green' : 'text-retro-red'}>{m.passes}/{m.runs}</span>
								{:else}—{/if}
							</Table.Cell>
						</Table.Row>
					{/each}
				</Table.Body>
			</Table.Root>
		</div>
	</Tabs.Content>

	<Tabs.Content value="commands" class="mt-4">
		<div class="mb-3 flex flex-wrap items-center justify-between gap-3">
			<p class="text-muted-foreground font-mono text-xs">{evals.commands.path}</p>
			<ToggleGroup.Root type="single" variant="outline" size="sm" value={verb} onValueChange={(v) => (verb = (v || 'all') as typeof verb)}>
				<ToggleGroup.Item value="all" class="px-3">All</ToggleGroup.Item>
				<ToggleGroup.Item value="fix" class="px-3">fix</ToggleGroup.Item>
				<ToggleGroup.Item value="shorten" class="px-3">shorten</ToggleGroup.Item>
				<ToggleGroup.Item value="plain" class="px-3">plain</ToggleGroup.Item>
				<ToggleGroup.Item value="explain" class="px-3">explain</ToggleGroup.Item>
			</ToggleGroup.Root>
		</div>
		<div class="bg-card ring-foreground/8 overflow-hidden rounded-2xl ring-1">
			<Table.Root>
				<Table.Header>
					<Table.Row>
						<Table.Head class="eyebrow">Case</Table.Head>
						<Table.Head class="eyebrow">Verb</Table.Head>
						<Table.Head class="eyebrow">What it tests</Table.Head>
						<Table.Head class="eyebrow text-right">Last run</Table.Head>
						<Table.Head class="eyebrow text-right">Time</Table.Head>
					</Table.Row>
				</Table.Header>
				<Table.Body>
					{#each commandCases as c (c.id)}
						{@const m = measuredById.get(c.id)}
						<Table.Row class="cursor-pointer" onclick={() => show(c.id)}>
							<Table.Cell class="font-mono text-xs">{c.id}</Table.Cell>
							<Table.Cell>
								<span class="rounded px-1.5 py-0.5 font-mono text-[10px] font-semibold text-[oklch(0.2_0.005_80)]" style="background: var(--retro-{verbColor[c.command]})">{c.command}</span>
							</Table.Cell>
							<Table.Cell class="max-w-[40ch] truncate text-sm">{c.note}</Table.Cell>
							<Table.Cell class="text-right font-mono text-xs">
								{#if m}
									<span class={m.passes === m.runs ? 'text-retro-green' : 'text-retro-red'}>{m.passes}/{m.runs}</span>
								{:else}—{/if}
							</Table.Cell>
							<Table.Cell class="text-muted-foreground text-right font-mono text-xs">
								{#if m?.ms != null}{m.ms} ms{#if m.firstWordsMs != null} · {m.firstWordsMs} first{/if}{:else}—{/if}
							</Table.Cell>
						</Table.Row>
					{/each}
				</Table.Body>
			</Table.Root>
		</div>
	</Tabs.Content>

	<Tabs.Content value="how" class="mt-4">
		<div class="record-prose text-sm">
			<p>From <code>packages/TimbreKit</code>. The model is stochastic by default and deterministic by decoding (ADR-0009); five repeats is the discipline either way.</p>
			<pre>swift run timbre-eval Fixtures/corpus.json --repeat 5
swift run timbre-eval --commands Fixtures/commands.json --repeat 5
swift run timbre-eval --audio-dir Fixtures/audio --corpus Fixtures/corpus.json</pre>
			<p>To record a run here, from <code>web/</code>:</p>
			<pre>pnpm run measure        # runs both corpora and writes src/lib/evals/measured.json
pnpm run sync:evals     # after editing a fixture</pre>
			<p>The cases are the source of truth; CI fails if this page's copy of them drifts. The measured numbers are not checked by CI — they need a Mac with the model — so the SHA and date on the card say how old they are.</p>
		</div>
	</Tabs.Content>
</Tabs.Root>

<Dialog.Root open={open !== undefined} onOpenChange={(isOpen) => { if (!isOpen) close(); }}>
	{#if open}
		{@const m = measuredById.get(open.id)}
		<Dialog.Content class="max-h-[88vh] overflow-y-auto sm:max-w-2xl">
			<Dialog.Header>
				<div class="flex flex-wrap items-center gap-2 text-xs">
					{#if isCommand(open)}
						<span class="rounded px-1.5 py-0.5 font-mono text-[10px] font-semibold text-[oklch(0.2_0.005_80)]" style="background: var(--retro-{verbColor[open.command]})">{open.command}</span>
					{:else}
						<span class="bg-retro-green rounded px-1.5 py-0.5 font-mono text-[10px] font-semibold text-[oklch(0.2_0.005_80)]">polisher</span>
					{/if}
					{#if m}
						<Badge variant="outline" class="font-mono">{m.passes}/{m.runs} last run{m.ms != null ? ` · ${m.ms} ms` : ''}</Badge>
					{/if}
					{#if !isCommand(open) && open.appContext}
						<Badge variant="secondary">in {open.appContext}</Badge>
					{/if}
				</div>
				<Dialog.Title class="font-mono text-xl">{open.id}</Dialog.Title>
				<Dialog.Description>{open.note}</Dialog.Description>
			</Dialog.Header>

			<div class="mt-2 space-y-5 text-sm">
				<div>
					<p class="eyebrow text-muted-foreground mb-1.5">{isCommand(open) ? 'Selection' : 'Transcript'}</p>
					<p class="bg-secondary/60 rounded-lg p-3 leading-relaxed">{isCommand(open) ? open.text : open.transcript}</p>
				</div>
				{#if !isCommand(open) && open.spoken}
					<div>
						<p class="eyebrow text-muted-foreground mb-1.5">Spoken (for the audio fixture)</p>
						<p class="bg-secondary/60 rounded-lg p-3 leading-relaxed">{open.spoken}</p>
					</div>
				{/if}
				<div class="grid gap-4 sm:grid-cols-2">
					<div>
						<p class="eyebrow text-retro-green mb-1.5">Must keep</p>
						<div class="flex flex-wrap gap-1.5">
							{#each open.required as word (word)}
								<span class="bg-secondary rounded-md px-2 py-0.5 font-mono text-xs">{word}</span>
							{:else}
								<span class="text-muted-foreground text-xs">—</span>
							{/each}
						</div>
					</div>
					<div>
						<p class="eyebrow text-retro-red mb-1.5">Must drop</p>
						<div class="flex flex-wrap gap-1.5">
							{#each open.forbidden as word (word)}
								<span class="bg-secondary rounded-md px-2 py-0.5 font-mono text-xs line-through">{word}</span>
							{:else}
								<span class="text-muted-foreground text-xs">—</span>
							{/each}
						</div>
					</div>
				</div>
				{#if isCommand(open) && open.exact}
					<div>
						<p class="eyebrow text-muted-foreground mb-1.5">Exact result required</p>
						<p class="bg-secondary/60 rounded-lg p-3 font-mono text-xs">{open.exact}</p>
					</div>
				{/if}
				{#if !isCommand(open) && (open.requiresPunctuation || open.requiresLineBreak)}
					<p class="text-muted-foreground text-xs">
						Also: {[open.requiresPunctuation && 'ends with punctuation', open.requiresLineBreak && 'contains a line break'].filter(Boolean).join(' · ')}.
					</p>
				{/if}
				{#if open.vocabulary.length || open.corrections.length || (isCommand(open) && open.acronyms.length)}
					<div class="grid gap-4 sm:grid-cols-3">
						{#if open.vocabulary.length}
							<div>
								<p class="eyebrow text-muted-foreground mb-1.5">Vocabulary</p>
								<p class="font-mono text-xs">{open.vocabulary.join(', ')}</p>
							</div>
						{/if}
						{#if open.corrections.length}
							<div>
								<p class="eyebrow text-muted-foreground mb-1.5">Corrections</p>
								{#each open.corrections as c (c.heard)}
									<p class="font-mono text-xs">{c.heard} → {c.meant}</p>
								{/each}
							</div>
						{/if}
						{#if isCommand(open) && open.acronyms.length}
							<div>
								<p class="eyebrow text-muted-foreground mb-1.5">Definitions</p>
								{#each open.acronyms as a (a.term)}
									<p class="font-mono text-xs">{a.term} — {a.meaning}</p>
								{/each}
							</div>
						{/if}
					</div>
				{/if}
			</div>
		</Dialog.Content>
	{/if}
</Dialog.Root>
