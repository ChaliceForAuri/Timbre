<script lang="ts">
	/// A keycap, drawn: two-tone plastic with a bevelled top face, the
	/// legend printed in ink. Grey by default; an accent colour marks a key
	/// Timbre owns. `hold` presses it and breathes a ring, `tap` clicks it
	/// once in a while, and `pressed` lets a parent drive it by hand.
	export type CapColor = 'grey' | 'dark' | 'red' | 'orange' | 'yellow' | 'green' | 'blue' | 'violet';

	let {
		symbol,
		name = '',
		gesture,
		color = 'grey',
		size = 'lg',
		pressed = false,
		caption = true,
		class: className = ''
	}: {
		symbol: string;
		name?: string;
		gesture?: 'hold' | 'tap';
		color?: CapColor;
		size?: 'lg' | 'md' | 'sm';
		pressed?: boolean;
		caption?: boolean;
		class?: string;
	} = $props();
</script>

<div class="inline-flex flex-col items-center gap-2 {className}">
	<div
		class="keycap {size} cap-{color} {gesture ?? ''}"
		class:down={pressed}
		role="img"
		aria-label="{gesture ? `${gesture} ` : ''}{name || symbol}"
	>
		<span class="face">
			<span class="legend">{symbol}</span>
			{#if name && size !== 'sm'}
				<span class="name">{name}</span>
			{/if}
		</span>
	</div>
	{#if gesture && caption}
		<span class="eyebrow" style="color: var(--ring-color)">{gesture}</span>
	{/if}
</div>

<style>
	.keycap {
		--top: var(--cap);
		--side: var(--cap-side);
		--ink: var(--foreground);
		--ring-color: var(--retro-green);
		position: relative;
		width: 5rem;
		height: 5rem;
		border-radius: 14px;
		background: var(--side);
		box-shadow:
			0 6px 0 0 color-mix(in oklch, var(--side) 78%, black),
			0 16px 28px -12px rgb(0 0 0 / 0.5);
		transform: translateY(0);
		transition:
			transform 0.12s ease,
			box-shadow 0.12s ease;
	}
	.md {
		width: 3.25rem;
		height: 3.25rem;
		border-radius: 11px;
	}
	.sm {
		width: 2.25rem;
		height: 2.25rem;
		border-radius: 8px;
		box-shadow:
			0 4px 0 0 color-mix(in oklch, var(--side) 78%, black),
			0 10px 18px -10px rgb(0 0 0 / 0.5);
	}
	.face {
		position: absolute;
		inset: 3px 4px 11px 4px;
		border-radius: 11px;
		background: linear-gradient(180deg, color-mix(in oklch, var(--top) 90%, white) 0%, var(--top) 100%);
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		color: var(--ink);
	}
	.md .face {
		inset: 2px 3px 9px 3px;
		border-radius: 8px;
	}
	.sm .face {
		inset: 2px 2px 6px 2px;
		border-radius: 6px;
	}
	.legend {
		font-family: var(--font-sans);
		font-weight: 600;
		font-size: 1.6rem;
		line-height: 1;
	}
	.md .legend {
		font-size: 1.2rem;
	}
	.sm .legend {
		font-size: 0.95rem;
	}
	.name {
		margin-top: 0.3rem;
		padding: 0 0.3rem;
		font-family: var(--font-mono);
		font-size: 0.55rem;
		line-height: 1.2;
		letter-spacing: 0.1em;
		text-transform: uppercase;
		text-align: center;
		opacity: 0.75;
	}

	/* Colours: the face is the accent, the side is the same plastic in
	   shadow, and the legend stays ink whatever the theme. */
	.cap-dark {
		--top: var(--cap-dark);
		--side: var(--cap-dark-side);
		--ink: oklch(0.94 0.004 80);
	}
	.cap-red {
		--top: var(--retro-red);
		--ring-color: var(--retro-red);
		--ink: oklch(0.99 0.002 80);
	}
	.cap-orange {
		--top: var(--retro-orange);
		--ring-color: var(--retro-orange);
		--ink: oklch(0.2 0.005 80);
	}
	.cap-yellow {
		--top: var(--retro-yellow);
		--ring-color: var(--retro-yellow);
		--ink: oklch(0.2 0.005 80);
	}
	.cap-green {
		--top: var(--retro-green);
		--ring-color: var(--retro-green);
		--ink: oklch(0.2 0.005 80);
	}
	.cap-blue {
		--top: var(--retro-blue);
		--ring-color: var(--retro-blue);
		--ink: oklch(0.2 0.005 80);
	}
	.cap-violet {
		--top: var(--retro-violet);
		--ring-color: var(--retro-violet);
		--ink: oklch(0.99 0.002 80);
	}
	.cap-red,
	.cap-orange,
	.cap-yellow,
	.cap-green,
	.cap-blue,
	.cap-violet {
		--side: color-mix(in oklch, var(--top) 72%, black);
	}

	.keycap::after {
		content: '';
		position: absolute;
		inset: -7px;
		border-radius: 20px;
		border: 2.5px solid var(--ring-color);
		opacity: 0;
		pointer-events: none;
	}
	.sm::after {
		inset: -5px;
		border-radius: 12px;
	}

	.down,
	.hold.down {
		transform: translateY(5px);
		box-shadow:
			0 1px 0 0 color-mix(in oklch, var(--side) 78%, black),
			0 5px 10px -6px rgb(0 0 0 / 0.5);
	}
	.hold {
		animation: press 4s ease-in-out infinite;
	}
	.hold::after {
		animation: ring 4s ease-out infinite;
	}
	.tap {
		animation: tap 4s ease-in-out infinite;
	}
	@keyframes press {
		0%,
		8% {
			transform: translateY(0);
		}
		12%,
		78% {
			transform: translateY(5px);
			box-shadow:
				0 1px 0 0 color-mix(in oklch, var(--side) 78%, black),
				0 5px 10px -6px rgb(0 0 0 / 0.5);
		}
		84%,
		100% {
			transform: translateY(0);
		}
	}
	@keyframes ring {
		0%,
		10% {
			opacity: 0;
			transform: scale(0.9);
		}
		16% {
			opacity: 0.95;
			transform: scale(1);
		}
		78% {
			opacity: 0.95;
			transform: scale(1);
		}
		90%,
		100% {
			opacity: 0;
			transform: scale(1.1);
		}
	}
	@keyframes tap {
		0%,
		40% {
			transform: translateY(0);
		}
		44%,
		50% {
			transform: translateY(5px);
			box-shadow:
				0 1px 0 0 color-mix(in oklch, var(--side) 78%, black),
				0 5px 10px -6px rgb(0 0 0 / 0.5);
		}
		56%,
		100% {
			transform: translateY(0);
		}
	}
	@media (prefers-reduced-motion: reduce) {
		.hold,
		.tap,
		.hold::after {
			animation: none;
		}
		.hold {
			transform: translateY(5px);
		}
		.hold::after {
			opacity: 0.95;
		}
	}
</style>
