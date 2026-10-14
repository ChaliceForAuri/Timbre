<script lang="ts">
	import Mark from '$lib/components/marketing/Mark.svelte';
	import KeyCap from '$lib/components/marketing/KeyCap.svelte';
	import { Badge } from '$lib/components/ui/badge';

	/// The brand, laid out so a choice can be made by looking: the mark,
	/// logotype candidates in real typefaces, the colours, the keycap.
	/// Each candidate family is loaded from Google Fonts for this page only.
	const candidates = [
		{
			family: 'Space Grotesk',
			query: 'Space+Grotesk:wght@500;700',
			note: 'Geometric, a little technical. The most "software" of the set.'
		},
		{
			family: 'Instrument Sans',
			query: 'Instrument+Sans:wght@500;600;700',
			note: 'Clean and even, slightly wide. Disappears into the page in a good way.'
		},
		{
			family: 'Bricolage Grotesque',
			query: 'Bricolage+Grotesque:opsz,wght@12..96,500;12..96,700',
			note: 'Warm, with character in the a, g and y. Reads as made by a person.'
		},
		{
			family: 'Manrope',
			query: 'Manrope:wght@600;800',
			note: 'Rounded corners, neutral. Calm at large sizes.'
		},
		{
			family: 'Outfit',
			query: 'Outfit:wght@500;700',
			note: 'Geometric and friendly. The closest to the keycap colours in spirit.',
			chosen: true
		},
		{
			family: 'Sora',
			query: 'Sora:wght@600;700',
			note: 'Precise, slightly squared. The most "device".'
		}
	];
	const fontsHref = `https://fonts.googleapis.com/css2?${candidates.map((c) => `family=${c.query}`).join('&')}&display=swap`;

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
	Outfit was chosen on 2026-10-13 (GDR-0019) and is served from this site, not from Google.
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

<!-- Logotype candidates -->
<section class="mt-12">
	<div class="flex items-baseline justify-between gap-4">
		<h2 class="text-3xl">Logotype candidates</h2>
		<p class="text-muted-foreground text-sm">Six families. Pick one, or name another.</p>
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
