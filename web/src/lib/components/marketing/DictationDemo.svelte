<script lang="ts">
	import { onMount } from 'svelte';
	import Keyboard from './Keyboard.svelte';
	import Pill from './Pill.svelte';
	import WindowMock from './WindowMock.svelte';

	/// The hero: one dictation, start to finish, on a loop, with the keyboard
	/// underneath showing which key is held. The raw words arrive as the
	/// transcriber would emit them — filler and all — then the cleaned
	/// sentence lands in the field. Reduced motion shows the end state.
	const raw = ['so', 'um', 'I', 'was', 'thinking', 'that', 'we', 'should', 'like', 'ship', 'it', 'on', 'friday'];
	const clean = 'So I was thinking that we should ship it on Friday.';

	type Phase = 'idle' | 'warming' | 'listening' | 'polishing' | 'inserted';
	let phase = $state<Phase>('inserted');
	let heard = $state(raw.length);
	let typed = $state(clean.length);
	let animate = $state(false);

	const liveText = $derived(raw.slice(0, heard).join(' '));
	const fieldText = $derived(phase === 'inserted' ? clean.slice(0, typed) : '');
	const holding = $derived(phase === 'warming' || phase === 'listening');

	onMount(() => {
		const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
		if (reduced) return;
		animate = true;

		let timers: number[] = [];
		const at = (ms: number, fn: () => void) => timers.push(window.setTimeout(fn, ms));

		const run = () => {
			timers.forEach(clearTimeout);
			timers = [];
			phase = 'warming';
			heard = 0;
			typed = 0;

			at(700, () => (phase = 'listening'));
			raw.forEach((_, i) => at(1100 + i * 190, () => (heard = i + 1)));
			const spoken = 1100 + raw.length * 190;
			at(spoken + 500, () => (phase = 'polishing'));
			at(spoken + 1500, () => (phase = 'inserted'));
			for (let i = 1; i <= clean.length; i++) at(spoken + 1500 + i * 22, () => (typed = i));
			at(spoken + 1500 + clean.length * 22 + 3400, run);
		};
		run();
		return () => timers.forEach(clearTimeout);
	});
</script>

<div class="relative">
	<div class="relative z-10 mx-auto max-w-[30rem]">
		<WindowMock title="New Message">
			<div class="text-muted-foreground mb-3 flex gap-3 border-b pb-2 text-xs">
				<span>To: <span class="text-foreground">Sam</span></span>
				<span>Subject: <span class="text-foreground">Release</span></span>
			</div>
			<p class="min-h-[3.2em]">
				{fieldText}<span
					class="caret bg-foreground ml-px inline-block h-[1.1em] w-px align-[-0.2em]"
					class:opacity-0={animate && phase !== 'inserted'}
				></span>
			</p>
		</WindowMock>

		<!-- The pill, where the app would put it: just under the caret. -->
		<div
			class="absolute -bottom-6 left-5 max-w-[calc(100%-2.5rem)]"
			class:hidden={animate && phase === 'inserted' && typed > 0}
		>
			{#if !animate}
				<Pill mode="listening" text={liveText} />
			{:else if phase === 'warming'}
				<Pill mode="warming" />
			{:else if phase === 'listening'}
				<Pill mode="listening" text={liveText} />
			{:else if phase === 'polishing'}
				<Pill mode="polishing" text="Cleaning up…" />
			{/if}
		</div>
	</div>

	<!-- The keyboard, with right Option held while the mic is open. -->
	<div class="mt-1 flex justify-center px-2">
		<Keyboard pressed={!animate || holding ? 'rightOption' : null} />
	</div>
</div>

<style>
	.caret {
		animation: blink 1.1s steps(2) infinite;
	}
	@keyframes blink {
		to {
			visibility: hidden;
		}
	}
	@media (prefers-reduced-motion: reduce) {
		.caret {
			animation: none;
		}
	}
</style>
