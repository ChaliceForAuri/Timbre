<script lang="ts">
	/// A keyboard key, drawn rather than photographed so it takes the site's
	/// palette in both themes. `hold` presses it down and breathes a ring;
	/// `tap` clicks it once in a while.
	let {
		symbol,
		name,
		gesture = 'hold'
	}: { symbol: string; name: string; gesture?: 'hold' | 'tap' } = $props();
</script>

<div class="flex flex-col items-center gap-2">
	<div class="keycap {gesture}" role="img" aria-label="{gesture} {name}">
		<span class="font-sans text-2xl leading-none font-medium">{symbol}</span>
		<span class="text-muted-foreground mt-1 font-mono text-[10px] tracking-widest uppercase">{name}</span>
	</div>
	<span class="text-primary font-mono text-xs tracking-[0.14em] uppercase">{gesture}</span>
</div>

<style>
	.keycap {
		position: relative;
		width: 4.5rem;
		height: 4.5rem;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		border-radius: 14px;
		border: 1px solid var(--border);
		background: linear-gradient(180deg, var(--card) 0%, var(--secondary) 100%);
		box-shadow:
			0 5px 0 0 var(--border),
			0 10px 22px -8px rgb(0 0 0 / 0.35);
		color: var(--foreground);
		transform: translateY(0);
	}
	.keycap::after {
		content: '';
		position: absolute;
		inset: -6px;
		border-radius: 20px;
		border: 2px solid var(--primary);
		opacity: 0;
		pointer-events: none;
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
			box-shadow:
				0 5px 0 0 var(--border),
				0 10px 22px -8px rgb(0 0 0 / 0.35);
		}
		12%,
		78% {
			transform: translateY(4px);
			box-shadow:
				0 1px 0 0 var(--border),
				0 4px 10px -6px rgb(0 0 0 / 0.35);
		}
		84%,
		100% {
			transform: translateY(0);
			box-shadow:
				0 5px 0 0 var(--border),
				0 10px 22px -8px rgb(0 0 0 / 0.35);
		}
	}
	@keyframes ring {
		0%,
		10% {
			opacity: 0;
			transform: scale(0.9);
		}
		16% {
			opacity: 0.9;
			transform: scale(1);
		}
		78% {
			opacity: 0.9;
			transform: scale(1);
		}
		90%,
		100% {
			opacity: 0;
			transform: scale(1.12);
		}
	}
	@keyframes tap {
		0%,
		40% {
			transform: translateY(0);
		}
		44%,
		50% {
			transform: translateY(4px);
			box-shadow:
				0 1px 0 0 var(--border),
				0 4px 10px -6px rgb(0 0 0 / 0.35);
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
			transform: translateY(4px);
		}
		.hold::after {
			opacity: 0.9;
		}
	}
</style>
