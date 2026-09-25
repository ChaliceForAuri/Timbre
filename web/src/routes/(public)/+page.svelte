<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import { site } from '$lib/site';
	import Compare from '$lib/components/marketing/Compare.svelte';
	import DictationDemo from '$lib/components/marketing/DictationDemo.svelte';
	import KeyCap from '$lib/components/marketing/KeyCap.svelte';
	import Pill from '$lib/components/marketing/Pill.svelte';
	import WindowMock from '$lib/components/marketing/WindowMock.svelte';

	/// Questions people actually ask before installing a dictation tool.
	/// Written as direct, quotable answers on purpose: answer engines lift
	/// short factual sentences, and the FAQPage schema below hands them the
	/// same text in a form they can parse.
	const faqs = [
		{
			q: 'Does Timbre send my voice anywhere?',
			a: 'No. Timbre sends nothing about you anywhere. Out of the box it makes no network requests at all; if you turn on update checks, it fetches one small version file from this website, carrying nothing. Speech recognition, text cleanup, read-aloud and the text commands all run on your Mac using Apple’s on-device models. You can verify this yourself with a network monitor such as Little Snitch.'
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
			a: 'Apple’s dictation transcribes what you say literally. Timbre adds a cleanup pass with an on-device language model: it removes filler words, fixes punctuation, and keeps your phrasing. It also reads selected text back to you, and it can fix, shorten or explain text you select.'
		},
		{
			q: 'Can it fix text I have already written?',
			a: 'Yes. Select the text, hold right Command and say “fix” — or say nothing, because a silent hold means fix. Say “shorten” to tighten it, “plain” to strip corporate filler and keep what it actually says, or “explain” to have it explained in a small card. Links, mentions, dates and numbers come back untouched. A word Timbre does not recognise does nothing, and Command-Z undoes any change.'
		},
		{
			q: 'What about acronyms and jargon it does not know?',
			a: 'Define them once in Settings under Dictionary. A defined term is explained from your definition, word for word, and every explanation card says whether the answer came from your dictionary or from the on-device model.'
		},
		{
			q: 'It keeps mishearing a word. Can I teach it?',
			a: 'Yes. Teach it a correction: what Timbre heard and what you meant. From then on that phrase is replaced before the cleanup step sees it, every time, and the corrected spelling joins your vocabulary.'
		},
		{
			q: 'Does it work without Apple Intelligence?',
			a: 'Speech recognition and read-aloud do. The cleanup pass and the text commands use Apple’s on-device language model, so without it you get the raw transcript, and fix falls back to the corrections you have taught.'
		},
		{
			q: 'Why does it need Accessibility permission?',
			a: 'To watch for the hotkeys while other apps are focused, and to paste the finished text where your cursor is. macOS classes both as Accessibility.'
		},
		{
			q: 'Does Timbre check for updates?',
			a: 'Only when you ask. Choose Check for Updates in the menu, or turn on a daily check in Settings; both fetch one small version file from this website and send nothing about you. Installing an update first checks that the download is Timbre, signed by its developer and notarized by Apple.'
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
					'Fixes, shortens or explains selected text',
					'Reads selected text aloud',
					'Personal dictionary: vocabulary, corrections, definitions',
					'No network requests unless you check for updates',
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
		content="Hold a key, speak, release. Cleaned-up text appears wherever you type. Tap another key to hear text read back; hold a third to fix, shorten or explain a selection. Speech recognition and AI run entirely on your Mac — zero network requests, no account, free."
	/>
	<meta property="og:title" content="Timbre — dictation that never leaves your Mac" />
	<meta property="og:description" content={site.description} />
	{@html `<script type="application/ld+json">${JSON.stringify(jsonLd)}<\/script>`}
</svelte:head>

<!-- Hero -->
<section class="mx-auto max-w-6xl px-6 pt-16 pb-20 sm:pt-24">
	<div class="grid items-center gap-14 lg:grid-cols-[1.05fr_1fr]">
		<div>
			<a
				href="/network"
				class="text-primary mb-5 inline-flex items-center gap-2 font-mono text-xs tracking-[0.14em] uppercase hover:underline"
			>
				<span class="bg-primary inline-block size-1.5 rounded-full"></span>
				Zero network requests<sup aria-label="see every request Timbre can make">*</sup>
			</a>

			<h1 class="max-w-[19ch] text-5xl leading-[1.05] sm:text-6xl">
				Dictation that never leaves your Mac.
			</h1>

			<p class="text-muted-foreground mt-6 max-w-[56ch] text-lg leading-relaxed">
				Hold a key and talk. Cleaned-up text lands wherever your cursor is — filler gone,
				punctuation right, your phrasing intact. Tap another key to hear anything read back. Hold a
				third on a selection to fix, shorten or explain it. All of it runs on your Mac, and none
				of it goes anywhere else.
			</p>

			<div class="mt-9 flex flex-wrap items-center gap-3">
				<Button href="/download" size="lg">Download for macOS</Button>
				<Button href="#three-keys" variant="ghost" size="lg" class="text-muted-foreground">
					The three keys ↓
				</Button>
			</div>

			<p class="text-muted-foreground mt-6 font-mono text-xs">
				Free · macOS 26 · Apple Silicon · Notarized by Apple · Source on GitHub
			</p>
		</div>

		<div class="pt-6 pr-3 pb-8 sm:pr-6">
			<DictationDemo />
		</div>
	</div>
</section>

<!-- The claim, stated so it can be checked -->
<section class="border-border/60 border-y">
	<div class="mx-auto max-w-6xl px-6 py-14">
		<h2 class="max-w-[24ch] text-2xl sm:text-3xl">Most private dictation apps ask you to trust them.</h2>
		<p class="text-muted-foreground mt-4 max-w-[62ch]">
			Timbre makes a claim you can falsify in thirty seconds: <strong class="text-foreground"
				>out of the box, it makes no network requests at all.</strong
			> Not telemetry, not crash reports. Point Little Snitch at it and watch nothing happen. Turn on update
			checks and it makes exactly one, to this website, carrying nothing —
			<a href="/network" class="text-primary underline underline-offset-4">every request it is capable of is listed here</a>.
			There is no cloud tier to fall back to, because there is no cloud. And the source is public, so you do
			not have to take even that on trust.
		</p>
	</div>
</section>

<!-- Three keys -->
<section id="three-keys" class="mx-auto max-w-6xl scroll-mt-16 px-6 py-20">
	<p class="text-primary font-mono text-xs tracking-[0.14em] uppercase">How it works</p>
	<h2 class="mt-3 text-3xl sm:text-4xl">Three keys. No window, no dock icon, no tour.</h2>
	<p class="text-muted-foreground mt-4 max-w-[58ch]">
		Timbre is a menu bar icon and a small pill that appears near your cursor. Everything it does
		starts with one of the modifier keys you already have under your thumbs.
	</p>

	<div class="mt-16 space-y-24">
		<!-- 1. Dictate -->
		<div class="grid items-center gap-10 lg:grid-cols-2">
			<div>
				<div class="mb-6"><KeyCap symbol="⌥" name="right option" gesture="hold" /></div>
				<h3 class="font-sans text-xl font-semibold">Hold, talk, release. It writes.</h3>
				<p class="text-muted-foreground mt-3 leading-relaxed">
					Apple’s on-device speech model transcribes as you speak; you see the words land in the
					pill. When you let go, an on-device language model removes the “um”, fixes the
					punctuation, splits the run-on into sentences — and does not rewrite you into someone
					else. The result is pasted where your cursor is, in any app.
				</p>
			</div>
			<div class="grid gap-3 sm:grid-cols-2">
				<div class="bg-card rounded-xl border p-4">
					<p class="text-muted-foreground mb-2 font-mono text-[11px] tracking-[0.12em] uppercase">
						What you said
					</p>
					<p class="text-muted-foreground text-[13.5px] leading-relaxed">
						so <s>um</s> I was thinking that <s>uh</s> we should probably <s>like</s> ship it on
						friday <s>I mean</s> the tests are green
					</p>
				</div>
				<div class="bg-card border-primary/40 rounded-xl border p-4">
					<p class="text-primary mb-2 font-mono text-[11px] tracking-[0.12em] uppercase">
						What landed
					</p>
					<p class="text-[13.5px] leading-relaxed">
						So I was thinking that we should probably ship it on Friday. The tests are green.
					</p>
				</div>
			</div>
		</div>

		<!-- 2. Read aloud -->
		<div class="grid items-center gap-10 lg:grid-cols-2">
			<div class="relative order-2 lg:order-1">
				<WindowMock title="Notes — Release plan">
					<p class="text-muted-foreground">
						The signing certificate expired on Tuesday, so
						<mark class="bg-accent text-foreground rounded px-0.5"
							>the release is delayed until Friday. We need to renew it before we can ship anything
							to customers</mark
						>, and the download page should say so.
					</p>
				</WindowMock>
				<div class="absolute -bottom-5 left-6"><Pill mode="reading" text="Reading  1.5×" /></div>
			</div>
			<div class="order-1 lg:order-2">
				<div class="mb-6"><KeyCap symbol="⌥" name="left option" gesture="tap" /></div>
				<h3 class="font-sans text-xl font-semibold">Tap, and it reads the selection back.</h3>
				<p class="text-muted-foreground mt-3 leading-relaxed">
					Select any text — an email, a paragraph you just wrote, a page — and tap. Tap again to
					speed up, mid-sentence, without losing your place. Hold to stop. It uses the best voice
					installed on your Mac, and tells you if a better one is a free download away.
				</p>
			</div>
		</div>

		<!-- 3. Command -->
		<div class="grid items-center gap-10 lg:grid-cols-2">
			<div>
				<div class="mb-6"><KeyCap symbol="⌘" name="right command" gesture="hold" /></div>
				<h3 class="font-sans text-xl font-semibold">Hold on a selection. Say fix, explain, shorten or plain.</h3>
				<p class="text-muted-foreground mt-3 leading-relaxed">
					<strong class="text-foreground">Fix</strong> corrects spelling, grammar and punctuation and
					changes nothing else — say nothing at all and that is what you get.
					<strong class="text-foreground">Shorten</strong> says the same thing in fewer words, in your
					voice. <strong class="text-foreground">Plain</strong> strips the corporate filler out of
					machine-sounding text and keeps what it actually says.
					<strong class="text-foreground">Explain</strong> shows what a word, acronym or passage
					means, in a card, without touching your text.
				</p>
				<p class="text-muted-foreground mt-3 leading-relaxed">
					It never guesses: a word it does not recognise does nothing. It never destroys: if the
					model cannot do the job safely, your text is left exactly as it was, and links, mentions,
					dates and numbers come back untouched either way. A change is an ordinary paste, so ⌘Z
					puts it back.
				</p>
			</div>
			<div class="relative">
				<WindowMock title="Message">
					<p>
						Can you take a look at the
						<mark class="bg-accent text-foreground rounded px-0.5">timber kit</mark> tests before the
						ADR review?
					</p>
				</WindowMock>
				<div class="absolute -bottom-5 left-6"><Pill mode="command" /></div>
				<div class="mt-12 flex justify-end">
					<Pill
						mode="explanation"
						text="ADR — Architecture Decision Record"
						caption="From your dictionary"
					/>
				</div>
			</div>
		</div>
	</div>
</section>

<!-- Dictionary -->
<section class="border-border/60 border-t">
	<div class="mx-auto max-w-6xl px-6 py-20">
		<div class="grid items-start gap-12 lg:grid-cols-[1fr_1.1fr]">
			<div>
				<p class="text-primary font-mono text-xs tracking-[0.14em] uppercase">Your dictionary</p>
				<h2 class="mt-3 text-3xl">It learns your words. Nobody else does.</h2>
				<p class="text-muted-foreground mt-4 leading-relaxed">
					A cloud app learns your vocabulary by sending it to a server. Timbre keeps a personal
					dictionary on your Mac and gets three things from it: the words the cleanup should prefer,
					the corrections for phrases it keeps mishearing, and the definitions that answer “explain”
					before any model does.
				</p>
			</div>
			<div class="grid gap-3">
				<div class="bg-card rounded-xl border p-4">
					<p class="text-muted-foreground mb-2 font-mono text-[11px] tracking-[0.12em] uppercase">Vocabulary</p>
					<div class="flex flex-wrap gap-1.5 text-[13px]">
						{#each ['TimbreKit', 'Supabase', 'Langfuse', 'SwiftUI', 'Pretorius'] as term (term)}
							<span class="bg-secondary rounded-md px-2 py-0.5">{term}</span>
						{/each}
					</div>
				</div>
				<div class="bg-card rounded-xl border p-4">
					<p class="text-muted-foreground mb-2 font-mono text-[11px] tracking-[0.12em] uppercase">Corrections</p>
					<dl class="space-y-1 text-[13px]">
						{#each [['timber kit', 'TimbreKit'], ['lang views', 'Langfuse'], ['my email', 'hugo@example.com']] as [heard, meant] (heard)}
							<div class="flex items-center gap-2">
								<dt class="text-muted-foreground">{heard}</dt>
								<span class="text-muted-foreground/60" aria-hidden="true">→</span>
								<dd>{meant}</dd>
							</div>
						{/each}
					</dl>
				</div>
				<div class="bg-card rounded-xl border p-4">
					<p class="text-muted-foreground mb-2 font-mono text-[11px] tracking-[0.12em] uppercase">Definitions</p>
					<dl class="space-y-1 text-[13px]">
						{#each [['ADR', 'Architecture Decision Record'], ['TCC', 'Transparency, Consent and Control — the macOS permission system']] as [term, meaning] (term)}
							<div class="flex items-baseline gap-2">
								<dt class="font-mono">{term}</dt>
								<span class="text-muted-foreground/60" aria-hidden="true">—</span>
								<dd class="text-muted-foreground">{meaning}</dd>
							</div>
						{/each}
					</dl>
				</div>
			</div>
		</div>
	</div>
</section>

<!-- Compare -->
<section class="border-border/60 border-t">
	<div class="mx-auto max-w-6xl px-6 py-20">
		<p class="text-primary font-mono text-xs tracking-[0.14em] uppercase">Compared</p>
		<h2 class="mt-3 text-3xl">Side by side, from their own pages.</h2>
		<div class="mt-8"><Compare /></div>
	</div>
</section>

<!-- FAQ: the AEO surface -->
<section class="border-border/60 border-t">
	<div class="mx-auto max-w-3xl px-6 py-20">
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
	<div class="mx-auto flex max-w-6xl flex-wrap items-center gap-6 px-6 py-14">
		<div>
			<h2 class="text-2xl">Try it on your own words.</h2>
			<p class="text-muted-foreground mt-2 max-w-[50ch] text-sm">
				Free for personal use. Notarized by Apple, so it installs without a fight. Built in the
				open — every decision is written down.
			</p>
		</div>
		<Button href="/download" size="lg" class="sm:ml-auto">Download</Button>
	</div>
</section>
