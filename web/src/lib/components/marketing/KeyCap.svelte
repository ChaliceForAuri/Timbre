<script lang="ts">
	/// A keycap, drawn simply: one flat face in its colour, the symbol on it,
	/// and a short caption underneath. The plastic is a 3-pixel edge, nothing
	/// more; the page's cleanliness matters more than the keyboard.
	export type CapColor = 'grey' | 'red' | 'orange' | 'yellow' | 'green' | 'blue' | 'violet';

	let {
		symbol,
		name = '',
		gesture,
		color = 'grey',
		size = 'lg',
		class: className = ''
	}: {
		symbol: string;
		name?: string;
		gesture?: 'hold' | 'tap';
		color?: CapColor;
		size?: 'lg' | 'md' | 'sm';
		class?: string;
	} = $props();

	const caption = $derived([name, gesture].filter(Boolean).join(' · '));
</script>

<div class="inline-flex flex-col items-start gap-2 {className}">
	<span class="keycap {size} cap-{color}" role="img" aria-label={caption || symbol}>
		{symbol}
	</span>
	{#if caption}
		<span class="eyebrow text-muted-foreground">{caption}</span>
	{/if}
</div>

<style>
	.keycap {
		--top: var(--cap);
		--ink: var(--foreground);
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 3.5rem;
		height: 3.5rem;
		border-radius: 12px;
		background: var(--top);
		color: var(--ink);
		font-family: var(--font-sans);
		font-weight: 600;
		font-size: 1.5rem;
		line-height: 1;
		box-shadow:
			0 3px 0 0 color-mix(in oklch, var(--top) 72%, black),
			0 10px 20px -12px rgb(0 0 0 / 0.35);
	}
	.md {
		width: 2.75rem;
		height: 2.75rem;
		border-radius: 10px;
		font-size: 1.2rem;
	}
	.sm {
		width: 2rem;
		height: 2rem;
		border-radius: 7px;
		font-size: 0.95rem;
		box-shadow: 0 2px 0 0 color-mix(in oklch, var(--top) 72%, black);
	}
	.cap-red {
		--top: var(--retro-red);
		--ink: oklch(0.99 0.002 80);
	}
	.cap-orange {
		--top: var(--retro-orange);
		--ink: oklch(0.2 0.005 80);
	}
	.cap-yellow {
		--top: var(--retro-yellow);
		--ink: oklch(0.2 0.005 80);
	}
	.cap-green {
		--top: var(--retro-green);
		--ink: oklch(0.2 0.005 80);
	}
	.cap-blue {
		--top: var(--retro-blue);
		--ink: oklch(0.2 0.005 80);
	}
	.cap-violet {
		--top: var(--retro-violet);
		--ink: oklch(0.99 0.002 80);
	}
</style>
