<script lang="ts">
	import { plans } from '$lib/plans';
	import { Badge } from '$lib/components/ui/badge';
	import { Progress } from '$lib/components/ui/progress';
	import * as Tabs from '$lib/components/ui/tabs';
	import { page } from '$app/state';

	const total = (plan: (typeof plans)[number]) => plan.done + plan.open;
	const percent = (plan: (typeof plans)[number]) =>
		total(plan) === 0 ? 0 : Math.round((plan.done / total(plan)) * 100);
	const initial = page.url.hash.slice(1) || plans[0]?.slug;
</script>

<svelte:head>
	<title>Plans — Timbre Backstage</title>
	<meta name="robots" content="noindex" />
</svelte:head>

<p class="eyebrow text-retro-green">Plans</p>
<h1 class="mt-2 text-4xl sm:text-5xl">What's next, in order.</h1>
<p class="text-muted-foreground mt-3 max-w-[62ch]">
	Each plan is a markdown file in the repo; a box is ticked by editing it, so progress is reviewed
	like everything else.
</p>

<Tabs.Root value={initial} class="mt-8">
	<Tabs.List>
		{#each plans as plan (plan.slug)}
			<Tabs.Trigger value={plan.slug}>
				{plan.title}
				{#if total(plan) > 0}
					<span class="text-muted-foreground ml-1 font-mono text-xs">{plan.done}/{total(plan)}</span>
				{/if}
			</Tabs.Trigger>
		{/each}
	</Tabs.List>

	{#each plans as plan (plan.slug)}
		<Tabs.Content value={plan.slug} class="mt-6">
			<section id={plan.slug} class="bg-card ring-foreground/8 scroll-mt-24 rounded-2xl p-6 ring-1 sm:p-8">
				<div class="flex flex-wrap items-end justify-between gap-4">
					<div>
						<h2 class="text-3xl">{plan.title}</h2>
						{#if plan.intro}
							<p class="text-muted-foreground mt-2 max-w-[65ch]">{plan.intro}</p>
						{/if}
					</div>
					{#if total(plan) > 0}
						<div class="min-w-56">
							<div class="flex items-baseline justify-between text-xs">
								<span class="text-muted-foreground font-mono">{plan.done} of {total(plan)} done</span>
								<Badge class={percent(plan) === 100 ? 'bg-retro-green text-[oklch(0.2_0.005_80)] hover:bg-retro-green' : ''} variant={percent(plan) === 100 ? 'default' : 'secondary'}>{percent(plan)}%</Badge>
							</div>
							<Progress value={percent(plan)} class="mt-1.5 h-1.5" />
						</div>
					{/if}
				</div>
				{#if plan.date}
					<p class="text-muted-foreground mt-2 font-mono text-xs">{plan.date} · {plan.path}</p>
				{/if}

				<div class="record-prose plan-prose mt-6">{@html plan.html}</div>
			</section>
		</Tabs.Content>
	{/each}
</Tabs.Root>
