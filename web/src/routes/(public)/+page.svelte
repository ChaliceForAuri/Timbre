<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import { site } from '$lib/site';
	import BeforeAfter from '$lib/components/marketing/BeforeAfter.svelte';
	import Compare from '$lib/components/marketing/Compare.svelte';
	import DictationDemo from '$lib/components/marketing/DictationDemo.svelte';
	import KeyCap from '$lib/components/marketing/KeyCap.svelte';
	import Pill from '$lib/components/marketing/Pill.svelte';
	import Stripe from '$lib/components/marketing/Stripe.svelte';
	import Ticker from '$lib/components/marketing/Ticker.svelte';
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
			a: 'macOS 26 or later, an Apple Silicon Mac, and Apple Intelligence enabled. Timbre grants itself no special access beyond Microphone and Accessibility, both of which you approve, and Reminders only if you use it for to-dos.'
		},
		{
			q: 'How is this different from the dictation built into macOS?',
			a: 'Apple’s dictation transcribes what you say literally. Timbre adds a cleanup pass with an on-device language model: it removes filler words, fixes punctuation, and keeps your phrasing. It also reads selected text back to you, it can fix, shorten, explain or plain-speak text you select, and it turns a spoken sentence into a Reminder.'
		},
		{
			q: 'Can it fix text I have already written?',
			a: 'Yes. Select the text, hold right Command and say “fix” — or say nothing, because a silent hold means fix. Say “shorten” to tighten it, “plain” to strip corporate filler and keep what it actually says, or “explain” to have it explained in a small card. Links, mentions, dates and numbers come back untouched. A word Timbre does not recognise does nothing, and Command-Z undoes any change.'
		},
		{
			q: 'Can it capture to-dos?',
			a: 'Yes. Hold right Command with nothing selected and say it — “call the dentist Thursday”. It lands in a Timbre list in Apple’s Reminders with the date read on your Mac, so it is on your iPhone and your watch too. Tap left Option with nothing selected to hear the list. You can pick any Reminders list in Settings.'
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
			a: 'Speech recognition, read-aloud and to-dos do. The cleanup pass and the text commands use Apple’s on-device language model, so without it you get the raw transcript, and fix falls back to macOS’s own spell checker plus the corrections you have taught.'
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
				image: `${site.origin}/og.png`,
				offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
				featureList: [
					'On-device speech recognition',
					'On-device AI text cleanup',
					'Fixes, shortens, explains or plain-speaks selected text',
					'Reads selected text aloud',
					'To-dos by voice into Apple Reminders',
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

	const claims = [
		'Zero network requests*',
		'No account',
		'Free',
		'On-device AI',
		'Notarized by Apple',
		'Open source',
		'macOS 26',
		'Apple Silicon',
		'Hold ⌥ · talk · release'
	];
</script>

<svelte:head>
	<title>Timbre — dictation for macOS that never touches the internet</title>
	<meta
		name="description"
		content="Hold a key, speak, release. Cleaned-up text appears wherever you type. Tap another key to hear text read back; hold a third to fix, shorten or explain a selection, or to drop a to-do into Reminders. Speech recognition and AI run entirely on your Mac — zero network requests, no account, free."
	/>
	<meta property="og:title" content="Timbre — dictation that never leaves your Mac" />
	<meta property="og:description" content={site.description} />
	{@html `<script type="application/ld+json">${JSON.stringify(jsonLd)}<\/script>`}
</svelte:head>

<!-- Hero -->
<section class="mx-auto max-w-6xl px-6 pt-14 pb-10 sm:pt-20">
	<div class="grid items-center gap-12 lg:grid-cols-[1.05fr_1fr]">
		<div class="min-w-0">
			<a href="/network" class="text-retro-green eyebrow mb-6 inline-flex items-center gap-2 hover:underline">
				<span class="bg-retro-green inline-block size-2 rounded-full"></span>
				Zero network requests<sup aria-label="see every request Timbre can make">*</sup>
			</a>

			<h1 class="max-w-[16ch] text-[3.4rem] sm:text-6xl xl:text-7xl">
				Dictation that <span class="underline-rainbow">never</span> leaves your Mac.
			</h1>

			<p class="text-muted-foreground mt-7 max-w-[54ch] text-lg leading-relaxed">
				Hold a key and talk. Cleaned-up text lands wherever your cursor is — filler gone,
				punctuation right, your phrasing intact. Tap another key to hear anything read back. Hold
				a third on a selection to fix, shorten or explain it, or with nothing selected to drop a
				to-do into Reminders. All of it runs on your Mac, and none of it goes anywhere else.
			</p>

			<div class="mt-9 flex flex-wrap items-center gap-3">
				<Button href="/download" size="lg" class="h-12 px-6 text-base">Download for macOS</Button>
				<Button href="#three-keys" variant="ghost" size="lg" class="text-muted-foreground h-12">
					How it works ↓
				</Button>
			</div>

			<p class="text-muted-foreground mt-7 font-mono text-xs">
				Free · macOS 26 · Apple Silicon · Notarized by Apple · Source on GitHub
			</p>
		</div>

		<div class="min-w-0 pt-6 pb-4 lg:pt-10">
			<DictationDemo />
		</div>
	</div>
</section>

<Ticker items={claims} />

<!-- The claim, stated so it can be checked -->
<section class="mx-auto max-w-6xl px-6 pt-20 pb-8">
	<div class="bg-case grid gap-10 rounded-3xl p-8 text-[oklch(0.94_0.004_80)] sm:p-12 lg:grid-cols-[1.1fr_1fr]">
		<div>
			<p class="eyebrow text-retro-yellow">The wedge</p>
			<h2 class="mt-3 max-w-[22ch] text-3xl sm:text-4xl">
				Most private dictation apps ask you to trust them.
			</h2>
			<p class="mt-5 max-w-[58ch] leading-relaxed text-[oklch(0.78_0.006_80)]">
				Timbre makes a claim you can falsify in thirty seconds:
				<strong class="text-[oklch(0.97_0.003_80)]">out of the box, it makes no network requests at all.</strong>
				Not telemetry, not crash reports. Point Little Snitch at it and watch nothing happen. Turn
				on update checks and it makes exactly one, to this website, carrying nothing —
				<a href="/network" class="decoration-retro-green underline decoration-2 underline-offset-4">
					every request it is capable of is listed here</a
				>. There is no cloud tier to fall back to, because there is no cloud. And the source is
				public, so you do not have to take even that on trust.
			</p>
		</div>
		<div class="self-center">
			<div class="overflow-hidden rounded-xl bg-[oklch(0.14_0.005_80)] font-mono text-[12.5px] shadow-[0_24px_40px_-24px_rgb(0_0_0/0.8)]">
				<div class="flex items-center gap-2 border-b border-white/10 px-3 py-2 text-[11px] text-[oklch(0.6_0.006_80)]">
					<span class="flex gap-1.5" aria-hidden="true">
						<span class="size-2.5 rounded-full bg-[#ff5f57]"></span>
						<span class="size-2.5 rounded-full bg-[#febc2e]"></span>
						<span class="size-2.5 rounded-full bg-[#28c840]"></span>
					</span>
					Terminal — while dictating
				</div>
				<pre class="px-4 py-4 leading-relaxed"><span class="text-retro-green">$</span> nettop -p Timbre
<span class="text-[oklch(0.6_0.006_80)]">                bytes_in   bytes_out
Timbre.1428            0           0</span>
<span class="text-retro-green">$</span> <span class="animate-pulse">▍</span></pre>
			</div>
			<p class="mt-3 font-mono text-[11px] text-[oklch(0.6_0.006_80)]">
				Update checks off. The list stays empty for as long as you like.
			</p>
		</div>
	</div>
</section>

<!-- Three keys -->
<section id="three-keys" class="mx-auto max-w-6xl scroll-mt-20 px-6 py-20">
	<p class="eyebrow text-retro-orange">How it works</p>
	<h2 class="mt-3 max-w-[18ch] text-4xl sm:text-5xl">Three keys. No window, no dock icon, no tour.</h2>
	<p class="text-muted-foreground mt-5 max-w-[58ch] text-lg">
		Timbre is a menu bar icon and a small pill that appears near your cursor. Everything it does
		starts with one of the modifier keys already under your thumbs.
	</p>

	<div class="mt-16 space-y-24">
		<!-- 1. Dictate -->
		<div class="grid items-center gap-10 lg:grid-cols-2">
			<div>
				<div class="mb-6"><KeyCap symbol="⌥" name="right option" gesture="hold" color="green" /></div>
				<h3 class="text-3xl">Hold, talk, release. It writes.</h3>
				<p class="text-muted-foreground mt-4 leading-relaxed">
					Apple’s on-device speech model transcribes as you speak; you see the words land in the
					pill. When you let go, an on-device language model removes the “um”, fixes the
					punctuation, splits the run-on into sentences — and does not rewrite you into someone
					else. The result is pasted where your cursor is, in any app.
				</p>
			</div>
			<BeforeAfter color="green">
				{#snippet before()}
					so <s>um</s> I was thinking that <s>uh</s> we should probably <s>like</s> ship it on
					friday <s>I mean</s> the tests are green
				{/snippet}
				{#snippet after()}
					So I was thinking that we should probably ship it on Friday. The tests are green.
				{/snippet}
			</BeforeAfter>
		</div>

		<!-- 2. Read aloud -->
		<div class="grid items-center gap-10 lg:grid-cols-2">
			<div class="relative order-2 lg:order-1">
				<WindowMock title="Notes — Release plan">
					<p class="text-muted-foreground">
						The signing certificate expired on Tuesday, so
						<mark class="bg-retro-yellow/50 text-foreground rounded px-0.5"
							>the release is delayed until Friday. We need to renew it before we can ship anything
							to customers</mark
						>, and the download page should say so.
					</p>
				</WindowMock>
				<div class="absolute -bottom-5 left-6"><Pill mode="reading" text="Reading  1.5×" /></div>
			</div>
			<div class="order-1 lg:order-2">
				<div class="mb-6"><KeyCap symbol="⌥" name="left option" gesture="tap" color="yellow" /></div>
				<h3 class="text-3xl">Tap, and it reads the selection back.</h3>
				<p class="text-muted-foreground mt-4 leading-relaxed">
					Select any text — an email, a paragraph you just wrote, a page — and tap. Tap again to
					speed up, mid-sentence, without losing your place. Hold to stop. It uses the best voice
					installed on your Mac, and tells you if a better one is a free download away.
				</p>
			</div>
		</div>

		<!-- 3. Command -->
		<div class="grid items-center gap-10 lg:grid-cols-2">
			<div>
				<div class="mb-6"><KeyCap symbol="⌘" name="right command" gesture="hold" color="orange" /></div>
				<h3 class="text-3xl">Hold on a selection. Say fix, explain, shorten or plain.</h3>
				<p class="text-muted-foreground mt-4 leading-relaxed">
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
						<mark class="bg-retro-orange/40 text-foreground rounded px-0.5">timber kit</mark> tests before
						the ADR review?
					</p>
				</WindowMock>
				<div class="absolute -bottom-5 left-6"><Pill mode="command" /></div>
				<div class="mt-12 flex justify-end">
					<Pill mode="explanation" text="ADR — Architecture Decision Record" caption="From your dictionary" />
				</div>
			</div>
		</div>

		<!-- 4. To-dos: the same key, nothing selected -->
		<div class="grid items-center gap-10 lg:grid-cols-2">
			<div class="relative order-2 lg:order-1">
				<div class="bg-card ring-foreground/8 rounded-xl p-4 ring-1 shadow-[0_28px_50px_-26px_rgb(0_0_0/0.55)]">
					<div class="mb-3 flex items-center gap-2">
						<span class="bg-retro-blue size-2.5 rounded-full"></span>
						<span class="text-sm font-semibold">Timbre</span>
						<span class="text-muted-foreground ml-auto font-mono text-[11px]">Reminders</span>
					</div>
					<ul class="space-y-2.5 text-[13.5px]">
						{#each [['Call the dentist', 'Thursday'], ['Renew the signing certificate', 'Friday, 09:00'], ['Send Sam the release notes', 'Today']] as [title, when] (title)}
							<li class="flex items-start gap-3">
								<span class="border-retro-blue mt-0.5 size-4 shrink-0 rounded-full border-2"></span>
								<span class="flex-1">
									{title}
									<span class="text-muted-foreground block text-xs">{when}</span>
								</span>
							</li>
						{/each}
					</ul>
				</div>
				<div class="absolute -bottom-5 left-6"><Pill mode="capture" text="call the dentist Thursday" /></div>
			</div>
			<div class="order-1 lg:order-2">
				<div class="mb-6 flex items-end gap-4">
					<KeyCap symbol="⌘" name="right command" gesture="hold" color="orange" />
					<span class="text-muted-foreground mb-7 font-mono text-xs">+ nothing selected</span>
				</div>
				<h3 class="text-3xl">Say a to-do. It lands in Reminders.</h3>
				<p class="text-muted-foreground mt-4 leading-relaxed">
					Hold the same key with nothing selected and say it — “call the dentist Thursday”. Timbre
					reads the date on your Mac and files it in a Timbre list in Apple’s Reminders, so it is on
					your iPhone and your watch a moment later, synced by Apple, not by us. Tap left Option
					with nothing selected to hear what is on the list.
				</p>
			</div>
		</div>
	</div>
</section>

<!-- Dictionary -->
<section class="mx-auto max-w-6xl px-6 py-8">
	<div class="grid items-start gap-12 lg:grid-cols-[1fr_1.1fr]">
		<div>
			<p class="eyebrow text-retro-violet">Your dictionary</p>
			<h2 class="mt-3 text-4xl">It learns your words. Nobody else does.</h2>
			<p class="text-muted-foreground mt-5 leading-relaxed">
				A cloud app learns your vocabulary by sending it to a server. Timbre keeps a personal
				dictionary on your Mac and gets three things from it: the words the cleanup should prefer,
				the corrections for phrases it keeps mishearing, and the definitions that answer “explain”
				before any model does.
			</p>
		</div>
		<div class="grid gap-3">
			<div class="bg-card ring-foreground/8 rounded-xl p-4 ring-1" style="box-shadow: inset 4px 0 0 0 var(--retro-green)">
				<p class="eyebrow text-muted-foreground mb-2 pl-2">Vocabulary</p>
				<div class="flex flex-wrap gap-1.5 pl-2 text-[13px]">
					{#each ['TimbreKit', 'Supabase', 'Langfuse', 'SwiftUI', 'Pretorius'] as term (term)}
						<span class="bg-secondary rounded-md px-2 py-0.5 font-mono text-xs">{term}</span>
					{/each}
				</div>
			</div>
			<div class="bg-card ring-foreground/8 rounded-xl p-4 ring-1" style="box-shadow: inset 4px 0 0 0 var(--retro-yellow)">
				<p class="eyebrow text-muted-foreground mb-2 pl-2">Corrections</p>
				<dl class="space-y-1 pl-2 text-[13px]">
					{#each [['timber kit', 'TimbreKit'], ['lang views', 'Langfuse'], ['my email', 'hugo@example.com']] as [heard, meant] (heard)}
						<div class="flex items-center gap-2">
							<dt class="text-muted-foreground">{heard}</dt>
							<span class="text-muted-foreground/60" aria-hidden="true">→</span>
							<dd class="font-medium">{meant}</dd>
						</div>
					{/each}
				</dl>
			</div>
			<div class="bg-card ring-foreground/8 rounded-xl p-4 ring-1" style="box-shadow: inset 4px 0 0 0 var(--retro-violet)">
				<p class="eyebrow text-muted-foreground mb-2 pl-2">Definitions</p>
				<dl class="space-y-1 pl-2 text-[13px]">
					{#each [['ADR', 'Architecture Decision Record'], ['TCC', 'Transparency, Consent and Control — the macOS permission system']] as [term, meaning] (term)}
						<div class="flex items-baseline gap-2">
							<dt class="font-mono font-medium">{term}</dt>
							<span class="text-muted-foreground/60" aria-hidden="true">—</span>
							<dd class="text-muted-foreground">{meaning}</dd>
						</div>
					{/each}
				</dl>
			</div>
		</div>
	</div>
</section>

<!-- Compare -->
<section id="compare" class="mx-auto max-w-6xl scroll-mt-20 px-6 py-20">
	<p class="eyebrow text-retro-blue">Compared</p>
	<h2 class="mt-3 text-4xl">Side by side, from their own pages.</h2>
	<div class="mt-8"><Compare /></div>
</section>

<!-- FAQ: the AEO surface -->
<section id="questions" class="mx-auto max-w-3xl scroll-mt-20 px-6 py-12">
	<p class="eyebrow text-retro-red">Questions</p>
	<h2 class="mt-3 text-4xl">Before you install it.</h2>
	<dl class="mt-10 space-y-8">
		{#each faqs as faq (faq.q)}
			<div class="border-border/70 border-t pt-6">
				<dt class="text-lg font-semibold">{faq.q}</dt>
				<dd class="text-muted-foreground mt-2 leading-relaxed">{faq.a}</dd>
			</div>
		{/each}
	</dl>
</section>

<!-- Close -->
<section class="mx-auto max-w-6xl px-6 py-16">
	<div class="bg-card ring-foreground/8 flex flex-wrap items-center gap-8 rounded-3xl p-8 ring-1 sm:p-12">
		<div class="flex-1">
			<Stripe height="5px" width="4rem" class="mb-6" />
			<h2 class="text-4xl">Try it on your own words.</h2>
			<p class="text-muted-foreground mt-3 max-w-[50ch]">
				Free for personal use. Notarized by Apple, so it installs without a fight. Built in the
				open — every decision is written down.
			</p>
		</div>
		<Button href="/download" size="lg" class="h-12 px-6 text-base">Download for macOS</Button>
	</div>
</section>
