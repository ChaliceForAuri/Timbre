<script lang="ts">
	import type { Snippet } from 'svelte';

	/// A number that means something, with the colour of the room it belongs
	/// to along its bottom edge and a link into that room.
	let {
		label,
		value,
		detail = '',
		href,
		color = 'green',
		children
	}: {
		label: string;
		value: string;
		detail?: string;
		href?: string;
		color?: 'red' | 'orange' | 'yellow' | 'green' | 'blue' | 'violet';
		children?: Snippet;
	} = $props();
</script>

<svelte:element
	this={href ? 'a' : 'div'}
	href={href ?? undefined}
	class="bg-card ring-foreground/8 block rounded-2xl p-5 ring-1 transition-shadow {href ? 'hover:ring-foreground/20' : ''}"
	style="box-shadow: inset 0 -4px 0 0 var(--retro-{color})"
>
	<p class="eyebrow text-muted-foreground">{label}</p>
	<p class="display mt-2 text-4xl">{value}</p>
	{#if detail}
		<p class="text-muted-foreground mt-1.5 text-sm">{detail}</p>
	{/if}
	{#if children}
		<div class="mt-3">{@render children()}</div>
	{/if}
</svelte:element>
