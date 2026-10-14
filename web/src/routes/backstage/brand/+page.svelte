<script lang="ts">
	import Mark from '$lib/components/marketing/Mark.svelte';
	import KeyCap from '$lib/components/marketing/KeyCap.svelte';
	import { Badge } from '$lib/components/ui/badge';

	/// The brand, laid out so a choice can be made by looking: the mark,
	/// logotype candidates in real typefaces, the colours, the keycap.
	/// Each candidate family is loaded from Google Fonts for this page only.
	/// Round two, 2026-10-14: rounded families, after Hugo named Instagram's
	/// face as the feel he likes — friendly, soft corners — while wanting to
	/// keep what Outfit gave the page. Outfit stays in the list as the one in
	/// use, so the comparison is against the real thing.
	const candidates = [
		{
			family: 'Outfit',
			query: 'Outfit:wght@400;500;700',
			note: 'Round one\u2019s choice. Geometric, not rounded.'
		},
		{
			family: 'Rubik',
			query: 'Rubik:wght@400;500;700',
			note: 'Geometric with softly rounded corners. Friendly without going soft — the closest to a keycap legend.'
		},
		{
			family: 'Figtree',
			query: 'Figtree:wght@400;500;700',
			note: 'Modern and warm, corners eased rather than rounded. Reads as a product, not a toy.'
		},
		{
			family: 'Red Hat Display',
			query: 'Red+Hat+Display:wght@400;500;700',
			note: 'Geometric with rounded terminals and a wide stance. Confident at headline size.'
		},
		{
			family: 'Nunito',
			query: 'Nunito:wght@400;600;800',
			note: 'Fully rounded terminals, the classic friendly sans. Very close to the Instagram feel.',
			chosen: true
		},
		{
			family: 'Onest',
			query: 'Onest:wght@400;500;700',
			note: 'Humanist with soft corners. The quietest of the rounded set.'
		},
		{
			family: 'Fredoka',
			query: 'Fredoka:wght@400;500;600;700',
			note: 'The bubble. Bold, round, playful — the furthest from "device", the nearest to "friend".'
		},
		{
			family: 'Comfortaa',
			query: 'Comfortaa:wght@400;700',
			note: 'Geometric and bubbly, built from circles. Distinctive; lowercase is its strength.'
		},
		{
			family: 'Baloo 2',
			query: 'Baloo+2:wght@400;600;800',
			note: 'Rounded and chunky. Warm at headline weight, a little heavy for body text.'
		}
	];
	const fontsHref = `https://fonts.googleapis.com/css2?${candidates.map((c) => `family=${c.query}`).join('&')}&display=swap`;

	/// Where the rounded rainbow sits under the word, if anywhere.
	const wordmarks = [
		{ label: 'mark + word', word: 'Timbre', mark: true, under: 'none', weight: 800, note: 'As the header shows it today. The rainbow lives in the mark only.' },
		{ label: 'mark + word, underlined', word: 'Timbre', mark: true, under: 'full', weight: 800, note: 'The rounded rainbow runs the width of the word.' },
		{ label: 'mark + word, short bar', word: 'Timbre', mark: true, under: 'short', weight: 800, note: 'A short rounded bar, left-aligned: a signature rather than an underline.' },
		{ label: 'word, underlined', word: 'Timbre', mark: false, under: 'full', weight: 800, note: 'No mark; the rainbow does the mark\u2019s job.' },
		{ label: 'lowercase, underlined', word: 'timbre', mark: true, under: 'full', weight: 800, note: 'Lowercase, which Nunito draws roundest.' },
		{ label: 'mark + word, lighter', word: 'Timbre', mark: true, under: 'full', weight: 700, note: 'One weight down, for a quieter header.' }
	];

	const colours = [
		['red', 'refusal, error, must drop'],
		['orange', 'command (right ⌘)'],
		['yellow', 'read (left ⌥)'],
		['green', 'dictate (right ⌥)'],
		['blue', 'to-do'],
		['violet', 'explanation card']
	];
</script>

<svelte:head>
	<title>Brand — Timbre Backstage</title>
	<meta name="robots" content="noindex" />
	<link rel="stylesheet" href={fontsHref} />
</svelte:head>

<p class="eyebrow text-retro-violet">Brand</p>
<h1 class="mt-2 text-4xl sm:text-5xl">The mark, the word, the colours.</h1>
<p class="text-muted-foreground mt-3 max-w-[62ch]">
	Decisions made by looking. The mark is settled; the typeface and the logotype are candidates,
	each shown as the header would show it, with a headline and a line of text in the same family.
	Nunito was chosen on 2026-10-14 (GDR-0020, after Outfit the day before) and is served from this
	site, not from Google; the candidates on this page load from Google Fonts for comparison only.
</p>

<!-- The mark -->
<section class="mt-10 grid gap-4 sm:grid-cols-2">
	<div class="bg-card ring-foreground/8 rounded-2xl p-6 ring-1">
		<p class="eyebrow text-muted-foreground">The mark, on paper</p>
		<div class="mt-4 flex items-end gap-6">
			<Mark size={96} />
			<Mark size={48} />
			<Mark size={32} />
			<Mark size={16} />
		</div>
	</div>
	<div class="bg-case rounded-2xl p-6">
		<p class="eyebrow text-[oklch(0.7_0.006_80)]">The mark, on charcoal</p>
		<div class="mt-4 flex items-end gap-6">
			<Mark size={96} />
			<Mark size={48} />
			<Mark size={32} />
			<Mark size={16} />
		</div>
	</div>
</section>

<!-- The wordmark -->
<section class="mt-12">
	<div class="flex items-baseline justify-between gap-4">
		<h2 class="text-3xl">The wordmark</h2>
		<p class="text-muted-foreground text-sm">Nunito. The rainbow has rounded ends now; the question is where it sits.</p>
	</div>
	<div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
		{#each wordmarks as w, i (w.label)}
			<div class="bg-card ring-foreground/8 rounded-2xl p-6 ring-1">
				<Badge variant="secondary" class="font-mono text-[10px]">{i + 1} · {w.label}</Badge>
				<div class="mt-6 flex h-16 items-center">
					{#if w.mark}<Mark size={32} class="mr-3 shrink-0" />{/if}
					<span class="relative inline-flex flex-col">
						<span class="text-[2rem] leading-none tracking-tight {w.weight === 700 ? 'font-bold' : 'font-extrabold'}">{w.word}</span>
						{#if w.under === 'full'}
							<span class="rainbow mt-1.5 block h-[5px] w-full rounded-full"></span>
						{:else if w.under === 'short'}
							<span class="rainbow mt-1.5 block h-[5px] w-10 rounded-full"></span>
						{/if}
					</span>
					{#if w.under === 'dot'}
						<span class="rainbow ml-2 block size-3 self-end rounded-full"></span>
					{/if}
				</div>
				<p class="text-muted-foreground mt-4 text-xs">{w.note}</p>
			</div>
		{/each}
	</div>
	<div class="bg-case mt-4 grid gap-4 rounded-2xl p-6 sm:grid-cols-3">
		{#each wordmarks.slice(0, 3) as w (w.label)}
			<div class="flex h-14 items-center text-[oklch(0.94_0.004_80)]">
				{#if w.mark}<Mark size={32} class="mr-3 shrink-0" />{/if}
				<span class="inline-flex flex-col">
					<span class="text-[2rem] leading-none font-extrabold tracking-tight">{w.word}</span>
					{#if w.under === 'full'}<span class="rainbow mt-1.5 block h-[5px] w-full rounded-full"></span>{:else if w.under === 'short'}<span class="rainbow mt-1.5 block h-[5px] w-10 rounded-full"></span>{/if}
				</span>
			</div>
		{/each}
	</div>
</section>

<!-- Logotype candidates -->
<section class="mt-12">
	<div class="flex items-baseline justify-between gap-4">
		<h2 class="text-3xl">Logotype candidates — round two, rounded</h2>
		<p class="text-muted-foreground text-sm">Outfit as the baseline, then eight rounded families. Pick one, or name another.</p>
	</div>
	<div class="mt-6 grid gap-4 lg:grid-cols-2">
		{#each candidates as c, i (c.family)}
			<article class="bg-card ring-foreground/8 rounded-2xl p-6 ring-1" style="font-family: '{c.family}', sans-serif">
				<div class="flex items-center justify-between gap-3">
					<span class="flex items-center gap-2">
						<Badge variant="secondary" class="font-mono text-[10px]">{String.fromCharCode(65 + i)} · {c.family}</Badge>
						{#if 'chosen' in c && c.chosen}
							<Badge class="bg-retro-green font-mono text-[10px] text-[oklch(0.2_0.005_80)] hover:bg-retro-green">in use</Badge>
						{/if}
					</span>
					<p class="text-muted-foreground font-sans text-xs">{c.note}</p>
				</div>

				<div class="mt-6 flex flex-wrap items-center gap-x-10 gap-y-5">
					<span class="flex items-center gap-2.5">
						<Mark size={28} />
						<span class="text-[1.5rem] leading-none font-bold tracking-tight">Timbre</span>
					</span>
					<span class="flex items-center gap-2.5">
						<Mark size={28} />
						<span class="text-[1.5rem] leading-none font-semibold tracking-tight">timbre</span>
					</span>
					<span class="text-[1.5rem] leading-none font-bold tracking-tight">Timbre</span>
				</div>

				<p class="mt-7 text-[2.1rem] leading-[1.08] font-bold tracking-[-0.02em] text-balance">
					Dictation that never leaves your Mac.
				</p>
				<p class="text-muted-foreground mt-3 text-[15px] leading-relaxed">
					Hold a key and talk. Cleaned-up text lands wherever your cursor is — filler gone,
					punctuation right, your phrasing intact.
				</p>
			</article>
		{/each}
	</div>
</section>

<!-- Colours -->
<section class="mt-12">
	<h2 class="text-3xl">Colours</h2>
	<p class="text-muted-foreground mt-2 max-w-[62ch]">
		Keycap grey and charcoal ink carry the page; the six accents each mean one thing (GDR-0017).
	</p>
	<div class="mt-6 grid gap-3 sm:grid-cols-3 lg:grid-cols-6">
		{#each colours as [name, meaning] (name)}
			<div class="bg-card ring-foreground/8 overflow-hidden rounded-2xl ring-1">
				<div class="h-16" style="background: var(--retro-{name})"></div>
				<div class="p-3">
					<p class="font-mono text-xs">retro-{name}</p>
					<p class="text-muted-foreground mt-1 text-xs">{meaning}</p>
				</div>
			</div>
		{/each}
	</div>
</section>

<!-- Keys -->
<section class="mt-12">
	<h2 class="text-3xl">The keys</h2>
	<p class="text-muted-foreground mt-2 max-w-[62ch]">
		One flat face, the symbol, a three-pixel edge, and the gesture as a caption. Nothing else.
	</p>
	<div class="mt-6 flex flex-wrap gap-10">
		<KeyCap symbol="⌥" name="right ⌥" gesture="hold" color="green" />
		<KeyCap symbol="⌥" name="left ⌥" gesture="tap" color="yellow" />
		<KeyCap symbol="⌘" name="right ⌘" gesture="hold" color="orange" />
		<KeyCap symbol="⌘" name="right ⌘ · nothing selected" gesture="hold" color="orange" size="md" />
		<KeyCap symbol="Z" color="grey" size="sm" />
	</div>
</section>
