<script lang="ts">
	/// A band of keycap tags on a slow loop: the claims, in the brand's
	/// colours. Reduced motion gets the same tags, wrapped and still.
	let { items }: { items: string[] } = $props();
	const colors = ['red', 'orange', 'yellow', 'green', 'blue', 'violet'];
</script>

<div class="ticker overflow-hidden py-1" aria-label={items.join(', ')}>
	<div class="track flex w-max gap-3">
		{#each [...items, ...items] as item, i (i)}
			<span
				class="tag bg-card text-foreground rounded-lg px-3 py-1.5 font-mono text-[11px] font-medium tracking-[0.12em] whitespace-nowrap uppercase"
				style="--c: var(--retro-{colors[i % colors.length]})"
				aria-hidden={i >= items.length}
			>
				{item}
			</span>
		{/each}
	</div>
</div>

<style>
	.tag {
		box-shadow:
			inset 0 0 0 1px color-mix(in oklch, var(--foreground) 8%, transparent),
			0 3px 0 0 var(--c);
	}
	.track {
		animation: scroll 48s linear infinite;
	}
	.ticker:hover .track {
		animation-play-state: paused;
	}
	@keyframes scroll {
		to {
			transform: translateX(-50%);
		}
	}
	@media (prefers-reduced-motion: reduce) {
		.track {
			animation: none;
			width: auto;
			flex-wrap: wrap;
			justify-content: center;
		}
		.track > :nth-child(n + 1000) {
			display: none;
		}
	}
</style>
