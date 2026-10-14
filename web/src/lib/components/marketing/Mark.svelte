<script lang="ts">
	/// The mark: four bars, the shape of a voice. On a charcoal tile it is the
	/// favicon and the app icon; without the tile it is the bare glyph, for
	/// sitting beside the wordmark where a tile would be a second box.
	let {
		size = 28,
		tile = true,
		weight = 2.6,
		class: className = ''
	}: { size?: number; tile?: boolean; weight?: number; class?: string } = $props();

	// Without the tile the box hugs the bars (they span x 6.7–25.3, y 7.7–24.3
	// of the 32-unit grid), so the glyph sits on the text's line.
	const box = $derived(tile ? '0 0 32 32' : `${8 - weight / 2 - 0.4} ${9 - weight / 2 - 0.4} ${16 + weight + 0.8} ${14 + weight + 0.8}`);
	const width = $derived(tile ? size : Math.round((size * (16 + weight + 0.8)) / (14 + weight + 0.8)));
</script>

<svg viewBox={box} {width} height={size} class={className} aria-hidden="true" focusable="false">
	{#if tile}
		<rect width="32" height="32" rx="7" fill="var(--case)" />
	{/if}
	<g stroke-width={weight} stroke-linecap="round">
		<line x1="8" y1="13" x2="8" y2="19" stroke="var(--retro-red)" />
		<line x1="13.3" y1="9" x2="13.3" y2="23" stroke="var(--retro-yellow)" />
		<line x1="18.6" y1="11.5" x2="18.6" y2="20.5" stroke="var(--retro-green)" />
		<line x1="24" y1="14.5" x2="24" y2="17.5" stroke="var(--retro-blue)" />
	</g>
</svg>
