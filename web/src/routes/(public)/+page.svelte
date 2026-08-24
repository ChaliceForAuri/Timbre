<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import { site } from '$lib/site';

	/// Questions people actually ask before installing a dictation tool.
	/// Written as direct, quotable answers on purpose: answer engines lift
	/// short factual sentences, and the FAQPage schema below hands them the
	/// same text in a form they can parse.
	const faqs = [
		{
			q: 'Does Timbre send my voice anywhere?',
			a: 'No. Timbre makes zero network requests. Speech recognition and text cleanup both run on your Mac using Apple’s on-device models. You can verify this yourself with a network monitor such as Little Snitch.'
		},
		{
			q: 'Does it work offline?',
			a: 'Yes, completely. There is no server to reach, so aeroplane mode changes nothing about how Timbre behaves.'
		},
		{
			q: 'Do I need an account?',
			a: 'No. There is no sign-up, no login, and no subscription. Download it and hold the key.'
		},
		{
			q: 'What does it cost?',
			a: 'Timbre is free for personal use.'
		},
		{
			q: 'What are the system requirements?',
			a: 'macOS 26 or later, an Apple Silicon Mac, and Apple Intelligence enabled. Timbre grants itself no special access beyond Microphone and Accessibility, both of which you approve.'
		},
		{
			q: 'How is this different from the dictation built into macOS?',
			a: 'Apple’s dictation transcribes what you say literally. Timbre adds a cleanup pass with an on-device language model: it removes filler words, fixes punctuation, and keeps your phrasing. It also reads selected text back to you.'
		},
		{
			q: 'Why does it need Accessibility permission?',
			a: 'To watch for the hotkey while other apps are focused, and to paste the finished text where your cursor is. macOS classes both as Accessibility.'
		}
	];

	/// Structured data. SoftwareApplication tells search engines what this is;
	/// FAQPage is what gets surfaced in AI answers and rich results.
	const jsonLd = {
		'@context': 'https://schema.org',
		'@graph': [
			{
				'@type': 'SoftwareApplication',
				name: 'Timbre',
				applicationCategory: 'UtilitiesApplication',
				operatingSystem: 'macOS 26',
				description: site.description,
				url: site.origin,
				offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
				featureList: [
					'On-device speech recognition',
					'On-device AI text cleanup',
					'Reads selected text aloud',
					'No network requests',
					'No account required'
				]
			},
			{
				'@type': 'FAQPage',
				mainEntity: faqs.map((f) => ({
					'@type': 'Question',
					name: f.q,
					acceptedAnswer: { '@type': 'Answer', text: f.a }
				}))
			}
		]
	};
</script>

<svelte:head>
	<title>Timbre — dictation for macOS that never touches the internet</title>
	<meta
		name="description"
		content="Hold a key, speak, release. Cleaned-up text appears wherever you type. Speech recognition and AI cleanup run entirely on your Mac — zero network requests, no account, free."
	/>
	<meta property="og:title" content="Timbre — dictation that never leaves your Mac" />
	<meta property="og:description" content={site.description} />
	{@html `<script type="application/ld+json">${JSON.stringify(jsonLd)}<\/script>`}
</svelte:head>

<!-- Hero -->
<section class="mx-auto max-w-5xl px-6 pt-20 pb-16 sm:pt-28">
	<p
		class="text-primary mb-5 inline-flex items-center gap-2 font-mono text-xs tracking-[0.14em] uppercase"
	>
		<span class="bg-primary inline-block size-1.5 rounded-full"></span>
		Zero network requests
	</p>

	<h1 class="max-w-[19ch] text-5xl leading-[1.05] sm:text-6xl">
		Dictation that never leaves your Mac.
	</h1>

	<p class="text-muted-foreground mt-6 max-w-[58ch] text-lg leading-relaxed">
		Hold <kbd class="bg-secondary text-secondary-foreground rounded px-1.5 py-0.5 font-mono text-sm"
			>right ⌥</kbd
		>, speak, release. Cleaned-up text lands in whatever app you're using — filler gone,
		punctuation right, your phrasing intact.
	</p>

	<div class="mt-9 flex flex-wrap items-center gap-3">
		<Button href="/download" size="lg">Download for macOS</Button>
		<Button href="/download" variant="ghost" size="lg" class="text-muted-foreground">
			Requirements →
		</Button>
	</div>

	<p class="text-muted-foreground mt-6 font-mono text-xs">
		Free · macOS 26+ · Apple Silicon · ~310 KB
	</p>
</section>

<!-- The claim, stated so it can be checked -->
<section class="border-border/60 border-y">
	<div class="mx-auto max-w-5xl px-6 py-14">
		<h2 class="max-w-[24ch] text-2xl sm:text-3xl">
			Most private dictation apps ask you to trust them.
		</h2>
		<p class="text-muted-foreground mt-4 max-w-[62ch]">
			Timbre makes a claim you can falsify in thirty seconds: <strong class="text-foreground"
				>it makes no network requests at all.</strong
			> Not telemetry, not crash reports, not an update check. Point Little Snitch at it and watch nothing
			happen. There is no cloud tier to fall back to, because there is no cloud.
		</p>
	</div>
</section>

<!-- What it does -->
<section class="mx-auto max-w-5xl px-6 py-16">
	<div class="grid gap-10 sm:grid-cols-3">
		<div>
			<h3 class="font-sans text-base font-semibold">It writes, you talk</h3>
			<p class="text-muted-foreground mt-2 text-sm leading-relaxed">
				An on-device language model removes "um", fixes punctuation, and splits run-on speech into
				sentences — without rewriting you into someone else.
			</p>
		</div>
		<div>
			<h3 class="font-sans text-base font-semibold">It reads back</h3>
			<p class="text-muted-foreground mt-2 text-sm leading-relaxed">
				Select any text and tap <kbd class="bg-secondary rounded px-1 py-0.5 font-mono text-xs"
					>left ⌥</kbd
				> to hear it. Tap again to speed up, mid-sentence, without losing your place.
			</p>
		</div>
		<div>
			<h3 class="font-sans text-base font-semibold">It stays out of the way</h3>
			<p class="text-muted-foreground mt-2 text-sm leading-relaxed">
				A menu bar icon and a small pill near your cursor. No window, no dock icon, no onboarding
				tour. It never steals focus from what you're typing into.
			</p>
		</div>
	</div>
</section>

<!-- FAQ: the AEO surface -->
<section class="border-border/60 border-t">
	<div class="mx-auto max-w-3xl px-6 py-16">
		<h2 class="text-2xl sm:text-3xl">Questions</h2>
		<dl class="mt-8 space-y-7">
			{#each faqs as faq (faq.q)}
				<div>
					<dt class="font-sans font-semibold">{faq.q}</dt>
					<dd class="text-muted-foreground mt-1.5 leading-relaxed">{faq.a}</dd>
				</div>
			{/each}
		</dl>
	</div>
</section>

<!-- Close -->
<section class="border-border/60 border-t">
	<div class="mx-auto flex max-w-5xl flex-wrap items-center gap-6 px-6 py-14">
		<div>
			<h2 class="text-2xl">Try it on your own words.</h2>
			<p class="text-muted-foreground mt-2 max-w-[50ch] text-sm">
				Free for personal use. Notarized by Apple, so it installs without a fight.
			</p>
		</div>
		<Button href="/download" size="lg" class="sm:ml-auto">Download</Button>
	</div>
</section>
