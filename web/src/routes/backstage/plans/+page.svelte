<script lang="ts">
	import { plans } from '$lib/plans';
	import { Badge } from '$lib/components/ui/badge';

	const total = (plan: (typeof plans)[number]) => plan.done + plan.open;
	const percent = (plan: (typeof plans)[number]) =>
		total(plan) === 0 ? 0 : Math.round((plan.done / total(plan)) * 100);
</script>

<svelte:head>
	<title>Plans — Timbre Backstage</title>
	<meta name="robots" content="noindex" />
</svelte:head>

<h1 class="text-3xl">Plans</h1>
<p class="text-muted-foreground mt-2 max-w-[65ch]">
	What is being built next and in what order. Each plan is a markdown file in the repo; a box is
	ticked by editing it, so progress is reviewed like everything else.
</p>

<nav class="mt-6 flex flex-wrap gap-2 text-sm">
	{#each plans as plan (plan.slug)}
		<a
			href="#{plan.slug}"
			class="bg-card hover:border-primary/40 rounded-full border px-3 py-1 transition-colors"
		>
			{plan.title}
			{#if total(plan) > 0}
				<span class="text-muted-foreground font-mono text-xs">· {plan.done}/{total(plan)}</span>
			{/if}
		</a>
	{/each}
</nav>

<div class="mt-10 space-y-14">
	{#each plans as plan (plan.slug)}
		<section id={plan.slug} class="scroll-mt-20">
			<div class="flex flex-wrap items-end justify-between gap-4">
				<div>
					<h2 class="text-2xl">{plan.title}</h2>
					{#if plan.intro}
						<p class="text-muted-foreground mt-2 max-w-[65ch]">{plan.intro}</p>
					{/if}
				</div>
				{#if total(plan) > 0}
					<div class="min-w-48">
						<div class="flex items-baseline justify-between text-xs">
							<span class="text-muted-foreground font-mono">{plan.done} of {total(plan)} done</span>
							<Badge variant={percent(plan) === 100 ? 'default' : 'secondary'}>{percent(plan)}%</Badge>
						</div>
						<div class="bg-muted mt-1.5 h-1.5 overflow-hidden rounded-full">
							<div class="bg-primary h-full rounded-full transition-all" style="width: {percent(plan)}%"></div>
						</div>
					</div>
				{/if}
			</div>
			{#if plan.date}
				<p class="text-muted-foreground mt-2 font-mono text-xs">{plan.date} · {plan.path}</p>
			{/if}

			<div class="record-prose plan-prose mt-6">{@html plan.html}</div>
		</section>
	{/each}
</div>
