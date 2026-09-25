<script lang="ts">
	import type { Snippet } from 'svelte';

	/// Two cards side by side: what went in, what came out. The "after"
	/// card carries the gesture's colour along its bottom edge.
	let {
		before,
		after,
		beforeLabel = 'What you said',
		afterLabel = 'What landed',
		color = 'green'
	}: {
		before: Snippet;
		after: Snippet;
		beforeLabel?: string;
		afterLabel?: string;
		color?: 'red' | 'orange' | 'yellow' | 'green' | 'blue' | 'violet';
	} = $props();
</script>

<div class="grid gap-3 sm:grid-cols-2">
	<div class="bg-card ring-foreground/8 rounded-xl p-4 ring-1">
		<p class="eyebrow text-muted-foreground mb-2">{beforeLabel}</p>
		<p class="text-muted-foreground text-[13.5px] leading-relaxed">{@render before()}</p>
	</div>
	<div class="bg-card ring-foreground/8 rounded-xl p-4 ring-1" style="box-shadow: inset 0 -4px 0 0 var(--retro-{color})">
		<p class="eyebrow mb-2" style="color: var(--retro-{color})">{afterLabel}</p>
		<p class="text-[13.5px] leading-relaxed">{@render after()}</p>
	</div>
</div>
