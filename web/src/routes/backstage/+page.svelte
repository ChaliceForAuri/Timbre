<script lang="ts">
	import * as Card from '$lib/components/ui/card';
	import { Badge } from '$lib/components/ui/badge';
	import { modules } from '$lib/university';

	const panels = [
		{
			title: 'University',
			body: `${modules.length} modules, from audio buffers to eval harnesses — written while building the thing they describe.`,
			href: '/backstage/university',
			status: 'ready'
		},
		{
			title: 'Evals',
			body: 'Polisher runs over time: pass rate against git history, per-case drill-downs, run diffs. Fed by timbre-eval --publish.',
			status: 'phase 2'
		},
		{
			title: 'Traces',
			body: 'Langfuse in parallel with the eval store — transcript in, prompt assembly, generation, guardrail, terminator.',
			status: 'phase 3'
		},
		{
			title: 'Lab',
			body: 'Live module playgrounds via timbre-eval --serve, so the browser drives the real Swift rather than a reimplementation.',
			status: 'phase 4'
		},
		{
			title: 'Feedback',
			body: 'GitHub issues labelled feedback, mirrored here and linkable to eval cases and releases.',
			status: 'phase 5'
		},
		{
			title: 'Customers',
			body: 'Stripe-fed CRM. Honour-system commercial licence, no in-app enforcement — a licence check is a network call.',
			status: 'phase 6'
		}
	];
</script>

<svelte:head>
	<title>Backstage — Timbre</title>
	<meta name="robots" content="noindex" />
</svelte:head>

<h1 class="text-3xl">Backstage</h1>
<p class="text-muted-foreground mt-2 max-w-[65ch]">
	The laboratory. Everything here is fed by the development side — eval runs, traces, imports —
	never by anyone's app. Timbre itself makes no network requests.
</p>

<div class="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
	{#each panels as panel (panel.title)}
		{@const ready = panel.status === 'ready'}
		<Card.Root class={ready ? 'hover:border-primary/40 transition-colors' : 'opacity-70'}>
			<Card.Header>
				<div class="flex items-start justify-between gap-2">
					<Card.Title class="text-lg">
						{#if ready && panel.href}
							<a href={panel.href} class="hover:text-primary">{panel.title}</a>
						{:else}
							{panel.title}
						{/if}
					</Card.Title>
					<Badge variant={ready ? 'default' : 'secondary'} class="shrink-0 text-xs">
						{panel.status}
					</Badge>
				</div>
			</Card.Header>
			<Card.Content>
				<p class="text-muted-foreground text-sm">{panel.body}</p>
			</Card.Content>
		</Card.Root>
	{/each}
</div>
