<script lang="ts">
	import Mark from './Mark.svelte';

	/// The lockup (GDR-0021): the bare bars beside "timbre", and since
	/// GDR-0025 how the word is said — "/tam·br/" — because almost nobody
	/// says it right the first time, and a name you are unsure how to say
	/// is a name you do not say. The respelling is set in the mono, muted,
	/// on the word's baseline, like a dictionary headword. It is hidden from
	/// screen readers: they already say the word correctly, and would read
	/// the slashes aloud.
	///
	/// `word` is the word's size in rem; everything else is proportional.
	/// `say` is the respelling, or false where the lockup is too small or
	/// already carries a second line (the Backstage sidebar).
	let {
		word = 1.5,
		say = '/tam·br/',
		class: className = ''
	}: { word?: number; say?: string | false; class?: string } = $props();

	// The bars at stroke 3 sit on the text's line; 22 px beside 1.5 rem is
	// the header's proportion (GDR-0021), kept for every size.
	const mark = $derived(Math.round(word * 14.67));
</script>

<span class="inline-flex items-center gap-2 {className}">
	<Mark size={mark} tile={false} class="shrink-0" />
	<span class="inline-flex items-baseline">
		<span class="display leading-none" style="font-size: {word}rem">timbre</span>
		{#if say}
			<span
				class="text-muted-foreground ml-[0.6em] font-mono leading-none tracking-wide whitespace-nowrap"
				style="font-size: {word * 0.5}rem"
				aria-hidden="true">{say}</span
			>
		{/if}
	</span>
</span>
