<script lang="ts">
	import { Badge } from '$lib/components/ui/badge';
	import { Progress } from '$lib/components/ui/progress';
	import Stat from '$lib/components/backstage/Stat.svelte';
	import { records } from '$lib/decisions';
	import { plans } from '$lib/plans';
	import { shipped, next } from '$lib/releases';
	import { evals, latest as measured } from '$lib/evals';
	import { launchDocs } from '$lib/launch';
	import { modules } from '$lib/university';
	import appcast from '../../../static/appcast.json';

	/// The overview is a dashboard of what the repo says: every number here
	/// is read from a committed file, so it is only ever as fresh as the last
	/// merge — which is the truth about the project anyway.
	const latestRelease = shipped[0];
	const launch = plans.find((p) => p.slug === 'launch-week') ?? plans[0];
	const launchTotal = launch ? launch.done + launch.open : 0;
	const launchPercent = launchTotal ? Math.round((launch.done / launchTotal) * 100) : 0;

	// Open launch items, by section, the way the week is actually worked.
	const openBySection = launch
		? launch.items
				.filter((item) => !item.done)
				.reduce<Record<string, string[]>>((groups, item) => {
					(groups[item.section] ??= []).push(item.text);
					return groups;
				}, {})
		: {};

	const newest = records.slice(0, 5);
	const counts = {
		adr: records.filter((r) => r.kind === 'ADR').length,
		gdr: records.filter((r) => r.kind === 'GDR').length
	};

	const dayFormat = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short' });
	const at = (iso: string) => new Date(`${iso}T12:00:00`);
	const firstSentence = (text: string) => text.split(/(?<=[.!?])\s/)[0];
</script>

<svelte:head>
	<title>Backstage — Timbre</title>
	<meta name="robots" content="noindex" />
</svelte:head>

<div class="flex flex-wrap items-end justify-between gap-4">
	<div>
		<p class="eyebrow text-retro-red">Overview</p>
		<h1 class="mt-2 text-4xl sm:text-5xl">Where Timbre is run.</h1>
		<p class="text-muted-foreground mt-3 max-w-[62ch]">
			Everything here is fed by the repo — releases, decisions, plans, eval runs — never by
			anyone's app. Timbre itself makes no network requests beyond the opt-in update check.
		</p>
	</div>
	{#if launch}
		<p class="text-muted-foreground font-mono text-xs">{launch.title} · {launch.date}</p>
	{/if}
</div>

<div class="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
	<Stat
		label="Shipped"
		value={latestRelease ? `v${latestRelease.version}` : '—'}
		detail={latestRelease?.date ? `${dayFormat.format(at(latestRelease.date))} · build ${appcast.latest.build}` : ''}
		href="/backstage/releases"
		color="orange"
	>
		{#if next}
			<Badge variant="secondary" class="font-mono text-[10px]">next: {next.items} changes queued</Badge>
		{/if}
	</Stat>
	<Stat
		label="Launch week"
		value="{launchPercent}%"
		detail={launch ? `${launch.done} of ${launchTotal} done · ${launch.open} open` : ''}
		href="/backstage/plans"
		color="green"
	>
		<Progress value={launchPercent} class="h-1.5" />
	</Stat>
	<Stat
		label="Measured"
		value="{measured.polisher.casesPassed}/{measured.polisher.cases} · {measured.commands.casesPassed}/{measured.commands.cases}"
		detail="polisher · commands, ×{measured.repeats} · {measured.sha} · {measured.date}"
		href="/backstage/evals"
		color="violet"
	/>
	<Stat
		label="Decisions"
		value={String(records.length)}
		detail="{counts.adr} ADRs · {counts.gdr} GDRs · newest {records[0]?.id}"
		href="/backstage/decisions"
		color="yellow"
	/>
</div>

<div class="mt-8 grid gap-6 lg:grid-cols-[1.15fr_1fr]">
	<!-- Still open this week -->
	<section class="bg-card ring-foreground/8 rounded-2xl p-6 ring-1">
		<div class="flex items-baseline justify-between gap-4">
			<h2 class="text-2xl">Still open this week</h2>
			<a href="/backstage/plans" class="text-muted-foreground hover:text-foreground text-sm">the plan →</a>
		</div>
		{#if Object.keys(openBySection).length === 0}
			<p class="text-muted-foreground mt-4 text-sm">Nothing. The week is done.</p>
		{:else}
			<div class="mt-5 space-y-5">
				{#each Object.entries(openBySection) as [section, items] (section)}
					<div>
						<p class="eyebrow text-muted-foreground">{section} · {items.length}</p>
						<ul class="mt-2 space-y-1.5 text-sm">
							{#each items as item (item)}
								<li class="flex gap-2.5">
									<span class="border-border mt-1 size-3.5 shrink-0 rounded-[4px] border-2"></span>
									<span class="leading-snug">{firstSentence(item)}</span>
								</li>
							{/each}
						</ul>
					</div>
				{/each}
			</div>
		{/if}
	</section>

	<div class="space-y-6">
		<!-- Next release -->
		{#if next}
			<section class="bg-card ring-foreground/8 rounded-2xl p-6 ring-1" style="box-shadow: inset 4px 0 0 0 var(--retro-orange)">
				<div class="flex items-baseline justify-between gap-4">
					<h2 class="text-2xl">Next release</h2>
					<a href="/backstage/releases#Unreleased" class="text-muted-foreground hover:text-foreground text-sm">notes →</a>
				</div>
				<p class="text-muted-foreground mt-2 text-sm">
					{next.items} changes in the Unreleased section:
					{next.sections.map((s) => `${(s.html.match(/<li>/g) ?? []).length} ${s.name.toLowerCase()}`).join(', ')}.
				</p>
			</section>
		{/if}

		<!-- Latest decisions -->
		<section class="bg-card ring-foreground/8 rounded-2xl p-6 ring-1">
			<div class="flex items-baseline justify-between gap-4">
				<h2 class="text-2xl">Latest decisions</h2>
				<a href="/backstage/decisions" class="text-muted-foreground hover:text-foreground text-sm">all {records.length} →</a>
			</div>
			<ul class="mt-4 divide-y">
				{#each newest as record (record.id)}
					<li>
						<a href="/backstage/decisions/{record.id}" class="group flex items-start gap-3 py-2.5">
							<span
								class="mt-0.5 shrink-0 rounded px-1.5 py-0.5 font-mono text-[10px] font-semibold text-[oklch(0.2_0.005_80)]"
								style="background: var(--retro-{record.kind === 'ADR' ? 'blue' : 'orange'})"
							>
								{record.kind}
							</span>
							<span class="min-w-0 flex-1">
								<span class="block truncate text-sm font-medium group-hover:underline">{record.title}</span>
								<span class="text-muted-foreground block font-mono text-[11px]">{record.id} · {dayFormat.format(at(record.date))}</span>
							</span>
						</a>
					</li>
				{/each}
			</ul>
		</section>

		<!-- Launch materials -->
		<section class="bg-card ring-foreground/8 rounded-2xl p-6 ring-1">
			<div class="flex items-baseline justify-between gap-4">
				<h2 class="text-2xl">Launch materials</h2>
				<a href="/backstage/launch" class="text-muted-foreground hover:text-foreground text-sm">open →</a>
			</div>
			<ul class="mt-4 space-y-2 text-sm">
				{#each launchDocs as doc (doc.slug)}
					<li class="flex items-center gap-3">
						<span class="text-muted-foreground w-16 shrink-0 font-mono text-[11px] uppercase">{doc.kind}</span>
						<a href="/backstage/launch#{doc.slug}" class="truncate hover:underline">{doc.title}</a>
						<span class="text-muted-foreground ml-auto shrink-0 text-xs">{doc.status.split(' — ')[0]}</span>
					</li>
				{/each}
			</ul>
		</section>
	</div>
</div>

<!-- The corpus, and the rooms still to build -->
<div class="mt-8 grid gap-6 lg:grid-cols-[1fr_1fr]">
	<section class="bg-card ring-foreground/8 rounded-2xl p-6 ring-1">
		<h2 class="text-2xl">The corpus</h2>
		<dl class="mt-4 grid grid-cols-3 gap-4">
			<div>
				<dt class="eyebrow text-muted-foreground">Polisher</dt>
				<dd class="display mt-1 text-3xl">{evals.polisher.cases.length}</dd>
				<dd class="text-muted-foreground text-xs">cases, five runs each</dd>
			</div>
			<div>
				<dt class="eyebrow text-muted-foreground">Commands</dt>
				<dd class="display mt-1 text-3xl">{evals.commands.cases.length}</dd>
				<dd class="text-muted-foreground text-xs">fix · shorten · plain · explain</dd>
			</div>
			<div>
				<dt class="eyebrow text-muted-foreground">Audio</dt>
				<dd class="display mt-1 text-3xl">{evals.audio.cases}</dd>
				<dd class="text-muted-foreground text-xs">fixtures through the transcriber</dd>
			</div>
		</dl>
		<p class="text-muted-foreground mt-4 text-sm">
			{modules.length} University modules explain how each number is produced.
		</p>
	</section>
	<section class="bg-card ring-foreground/8 rounded-2xl p-6 ring-1">
		<h2 class="text-2xl">Rooms still to build</h2>
		<ul class="mt-4 space-y-3 text-sm">
			<li class="flex gap-3"><Badge variant="secondary" class="w-8 shrink-0 justify-center font-mono text-[10px]">p3</Badge><span><strong>Traces.</strong> Langfuse beside the eval store: transcript in, prompt, generation, guardrail, terminator.</span></li>
			<li class="flex gap-3"><Badge variant="secondary" class="w-8 shrink-0 justify-center font-mono text-[10px]">p4</Badge><span><strong>Lab.</strong> Live module playgrounds via <code class="font-mono text-xs">timbre-eval --serve</code>, so the browser drives the real Swift.</span></li>
			<li class="flex gap-3"><Badge variant="secondary" class="w-8 shrink-0 justify-center font-mono text-[10px]">p5</Badge><span><strong>Feedback.</strong> GitHub issues labelled feedback, mirrored here and linked to cases and releases.</span></li>
			<li class="flex gap-3"><Badge variant="secondary" class="w-8 shrink-0 justify-center font-mono text-[10px]">p6</Badge><span><strong>Customers.</strong> Stripe-fed, honour-system commercial licence, no in-app enforcement ever.</span></li>
		</ul>
	</section>
</div>
