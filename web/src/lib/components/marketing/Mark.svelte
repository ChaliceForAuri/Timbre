<script lang="ts">
	/// The mark: four bars, the shape of a voice, on a charcoal tile — the
	/// favicon and the app icon, drawn inline so it takes the palette from
	/// the page and stays crisp at any size.
	let { size = 28, class: className = '' }: { size?: number; class?: string } = $props();
</script>

<svg
	viewBox="0 0 32 32"
	width={size}
	height={size}
	class={className}
	aria-hidden="true"
	focusable="false"
>
	<rect width="32" height="32" rx="7" fill="var(--case)" />
	<g stroke-width="2.6" stroke-linecap="round">
		<line x1="8" y1="13" x2="8" y2="19" stroke="var(--retro-red)" />
		<line x1="13.3" y1="9" x2="13.3" y2="23" stroke="var(--retro-yellow)" />
		<line x1="18.6" y1="11.5" x2="18.6" y2="20.5" stroke="var(--retro-green)" />
		<line x1="24" y1="14.5" x2="24" y2="17.5" stroke="var(--retro-blue)" />
	</g>
</svg>
