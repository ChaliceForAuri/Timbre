<script lang="ts">
	/// The bottom of a Mac keyboard, drawn in the retro two-tone: charcoal
	/// case, grey caps, and the three keys Timbre owns in their colours.
	/// `pressed` pushes one of them down so the demo above can show which.
	export type TimbreKey = 'leftOption' | 'rightOption' | 'rightCommand';

	let { pressed = null, class: className = '' }: { pressed?: TimbreKey | null; class?: string } =
		$props();

	type Key = { l: string; w: number; id?: TimbreKey; color?: string; sub?: string };
	const rows: Key[][] = [
		[
			{ l: '⇧', w: 2.35 },
			...'ZXCVBNM'.split('').map((l) => ({ l, w: 1 })),
			{ l: ',', w: 1 },
			{ l: '.', w: 1 },
			{ l: '/', w: 1 },
			{ l: '⇧', w: 2.35 }
		],
		[
			{ l: 'fn', w: 1 },
			{ l: '⌃', w: 1 },
			{ l: '⌥', w: 1, id: 'leftOption', color: 'yellow', sub: 'read' },
			{ l: '⌘', w: 1.25 },
			{ l: '', w: 5.1 },
			{ l: '⌘', w: 1.25, id: 'rightCommand', color: 'orange', sub: 'command' },
			{ l: '⌥', w: 1, id: 'rightOption', color: 'green', sub: 'dictate' },
			{ l: '◀', w: 1 },
			{ l: '▲', w: 1, sub: '▼' },
			{ l: '▶', w: 1 }
		]
	];
</script>

<div class="board {className}" role="img" aria-label="The bottom rows of a Mac keyboard, with left Option, right Command and right Option highlighted">
	{#each rows as row, r (r)}
		<div class="row">
			{#each row as key, i (i)}
				<div
					class="key {key.color ? `cap-${key.color}` : ''}"
					class:down={key.id !== undefined && key.id === pressed}
					class:owned={key.id !== undefined}
					style="--w: {key.w}"
				>
					<span class="face">
						<span class="legend" class:small={key.l.length > 1}>{key.l}</span>
						{#if key.sub && key.id}
							<span class="sub">{key.sub}</span>
						{:else if key.sub}
							<span class="legend small">{key.sub}</span>
						{/if}
					</span>
				</div>
			{/each}
		</div>
	{/each}
</div>

<style>
	.board {
		--u: clamp(1.5rem, 3.6vw, 2.3rem);
		--gap: calc(var(--u) * 0.14);
		display: flex;
		flex-direction: column;
		gap: var(--gap);
		width: max-content;
		max-width: 100%;
		padding: calc(var(--u) * 0.45) calc(var(--u) * 0.5) calc(var(--u) * 0.55);
		border-radius: calc(var(--u) * 0.55) calc(var(--u) * 0.55) calc(var(--u) * 0.35) calc(var(--u) * 0.35);
		background: linear-gradient(180deg, color-mix(in oklch, var(--case) 88%, white) 0%, var(--case) 100%);
		box-shadow:
			0 10px 0 0 color-mix(in oklch, var(--case) 70%, black),
			0 30px 50px -20px rgb(0 0 0 / 0.6);
		transform: perspective(1400px) rotateX(24deg);
		transform-origin: 50% 100%;
	}
	.row {
		display: flex;
		gap: var(--gap);
	}
	.key {
		--top: var(--cap);
		--side: var(--cap-side);
		--ink: var(--foreground);
		position: relative;
		width: calc(var(--u) * var(--w) + var(--gap) * (var(--w) - 1));
		height: var(--u);
		border-radius: calc(var(--u) * 0.22);
		background: var(--side);
		box-shadow: 0 calc(var(--u) * 0.16) 0 0 color-mix(in oklch, var(--side) 78%, black);
		transition:
			transform 0.1s ease,
			box-shadow 0.1s ease;
	}
	.face {
		position: absolute;
		inset: 8% 7% 22% 7%;
		border-radius: calc(var(--u) * 0.17);
		background: linear-gradient(180deg, color-mix(in oklch, var(--top) 90%, white) 0%, var(--top) 100%);
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		color: var(--ink);
		line-height: 1;
	}
	.legend {
		font-family: var(--font-sans);
		font-weight: 600;
		font-size: calc(var(--u) * 0.46);
	}
	.legend.small {
		font-size: calc(var(--u) * 0.3);
		opacity: 0.85;
	}
	.sub {
		font-family: var(--font-mono);
		font-size: calc(var(--u) * 0.2);
		letter-spacing: 0.08em;
		text-transform: uppercase;
		margin-top: calc(var(--u) * 0.05);
	}
	.owned .legend {
		font-size: calc(var(--u) * 0.4);
	}
	.cap-yellow {
		--top: var(--retro-yellow);
		--ink: oklch(0.2 0.005 80);
	}
	.cap-orange {
		--top: var(--retro-orange);
		--ink: oklch(0.2 0.005 80);
	}
	.cap-green {
		--top: var(--retro-green);
		--ink: oklch(0.2 0.005 80);
	}
	.cap-yellow,
	.cap-orange,
	.cap-green {
		--side: color-mix(in oklch, var(--top) 72%, black);
	}
	.down {
		transform: translateY(calc(var(--u) * 0.13));
		box-shadow: 0 calc(var(--u) * 0.03) 0 0 color-mix(in oklch, var(--side) 78%, black);
	}
	@media (prefers-reduced-motion: reduce) {
		.key {
			transition: none;
		}
	}
</style>
