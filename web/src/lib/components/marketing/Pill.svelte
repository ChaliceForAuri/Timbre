<script lang="ts">
	/// The overlay as it appears in the app: waveform, sparkle, a card with
	/// its source caption. Each mode carries its gesture's colour, so the
	/// pill reads as part of the page's system rather than a screenshot.
	let {
		mode = 'listening',
		text = '',
		caption = ''
	}: {
		mode?: 'warming' | 'listening' | 'polishing' | 'command' | 'reading' | 'explanation' | 'capture' | 'notice';
		text?: string;
		caption?: string;
	} = $props();

	const isCard = $derived(mode === 'explanation');
	const live = $derived(mode === 'listening' || mode === 'command' || mode === 'capture');
	const tint = $derived(
		mode === 'reading'
			? 'var(--retro-yellow)'
			: mode === 'command'
				? 'var(--retro-orange)'
				: mode === 'explanation'
					? 'var(--retro-violet)'
					: mode === 'capture'
						? 'var(--retro-blue)'
						: mode === 'polishing'
							? 'var(--retro-blue)'
							: 'var(--retro-green)'
	);
	const label = $derived(
		mode === 'warming'
			? 'Waking the mic…'
			: mode === 'command' && !text
				? 'fix · explain · shorten · plain'
				: mode === 'capture' && !text
					? 'Say a to-do…'
					: mode === 'listening' && !text
						? 'Listening…'
						: text
	);
	const dim = $derived(label === 'Listening…' || label === 'Waking the mic…' || (live && !text));
</script>

<div
	class="pill inline-flex max-w-full gap-3 rounded-2xl px-3.5 py-2.5 text-[13px] font-medium {isCard
		? 'items-start'
		: 'items-center'}"
	style="--tint: {tint}"
>
	{#if mode === 'warming' || live}
		<span class="flex h-[18px] w-[34px] items-center justify-center gap-[2.5px]" aria-hidden="true">
			{#each [0, 1, 2, 3, 4] as i (i)}
				<span class="bar w-[3px] rounded-full {live ? 'live' : ''}" style="--i: {i}"></span>
			{/each}
		</span>
	{:else if mode === 'polishing'}
		<svg class="sparkle size-4 shrink-0" viewBox="0 0 24 24" fill="var(--tint)" aria-hidden="true">
			<path d="M12 2l1.8 5.2L19 9l-5.2 1.8L12 16l-1.8-5.2L5 9l5.2-1.8L12 2zm7 11l.9 2.6 2.6.9-2.6.9L19 20l-.9-2.6-2.6-.9 2.6-.9L19 13zM5 14l.7 2 2 .7-2 .7L5 19.4l-.7-2-2-.7 2-.7L5 14z" />
		</svg>
	{:else if mode === 'reading'}
		<svg class="size-4 shrink-0" viewBox="0 0 24 24" fill="var(--tint)" aria-hidden="true">
			<path d="M4 9v6h4l5 4V5L8 9H4zm11.5 3a3.5 3.5 0 0 0-2-3.15v6.3a3.5 3.5 0 0 0 2-3.15zm-2-7.6v2.1a5.5 5.5 0 0 1 0 11v2.1a7.5 7.5 0 0 0 0-15.2z" />
		</svg>
	{:else if mode === 'explanation'}
		<svg class="mt-0.5 size-4 shrink-0" viewBox="0 0 24 24" fill="var(--tint)" aria-hidden="true">
			<path d="M4 4h16a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-9l-5 4v-4H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2zm2 4v2h12V8H6zm0 4v2h8v-2H6z" />
		</svg>
	{:else}
		<svg class="size-4 shrink-0" viewBox="0 0 24 24" fill="var(--tint)" aria-hidden="true">
			<path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm-1.2 14.4-4-4 1.4-1.4 2.6 2.6 5.6-5.6 1.4 1.4-7 7z" />
		</svg>
	{/if}

	<span class="flex min-w-0 flex-col gap-1.5">
		<span class="{isCard ? 'whitespace-normal' : 'truncate'} {dim ? 'text-muted-foreground' : ''}">
			{label}
		</span>
		{#if caption}
			<span class="text-muted-foreground font-mono text-[10.5px] tracking-wide">{caption}</span>
		{/if}
	</span>
</div>

<style>
	.pill {
		background: color-mix(in oklch, var(--card) 86%, transparent);
		backdrop-filter: blur(18px);
		-webkit-backdrop-filter: blur(18px);
		box-shadow:
			inset 0 0 0 1px color-mix(in oklch, var(--foreground) 8%, transparent),
			inset 0 -3px 0 0 color-mix(in oklch, var(--tint) 85%, transparent),
			0 14px 30px -12px rgb(0 0 0 / 0.4);
	}
	.bar {
		height: 4px;
		background: var(--tint);
	}
	.bar.live {
		animation: bar 1.1s ease-in-out infinite;
		animation-delay: calc(var(--i) * -0.17s);
	}
	@keyframes bar {
		0%,
		100% {
			height: 4px;
		}
		30% {
			height: 16px;
		}
		60% {
			height: 8px;
		}
	}
	.sparkle {
		animation: twinkle 1.4s ease-in-out infinite;
	}
	@keyframes twinkle {
		0%,
		100% {
			opacity: 0.55;
			transform: scale(0.94);
		}
		50% {
			opacity: 1;
			transform: scale(1.06);
		}
	}
	@media (prefers-reduced-motion: reduce) {
		.bar.live,
		.sparkle {
			animation: none;
		}
		.bar.live {
			height: 10px;
		}
	}
</style>
