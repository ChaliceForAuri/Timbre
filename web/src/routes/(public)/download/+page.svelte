<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import KeyCap from '$lib/components/marketing/KeyCap.svelte';
	import Stripe from '$lib/components/marketing/Stripe.svelte';
	// The same file the app's update check reads, written by tools/release.sh:
	// the download button can never point at a different version.
	import appcast from '../../../../static/appcast.json';

	const release = appcast.latest;
	// The disk image is the download page's format; the zip stays the update
	// format. Releases before the image have only the zip.
	const dmg = (release as { dmgURL?: string }).dmgURL ?? null;
	const local = (url: string) => url.replace('https://timbre.hugopretorius.dev', '');
	const megabytes = (release.size / 1_000_000).toFixed(1);
	const published = new Intl.DateTimeFormat('en-GB', { dateStyle: 'long' }).format(
		new Date(`${release.published}T12:00:00`)
	);
	const notes = release.notes
		.split('\n')
		.map((line) => line.trim())
		.filter(Boolean);

	const requirements = [
		['macOS 26 or later', 'Timbre uses SpeechAnalyzer and Foundation Models, both introduced in macOS 26.', 'green'],
		['Apple Silicon', 'The speech and language models run on the Neural Engine.', 'yellow'],
		[
			'Apple Intelligence enabled',
			'Without it, dictation, read-aloud and to-dos still work; the cleanup pass and the text commands need the on-device model.',
			'orange'
		]
	];

	const steps = [
		dmg
			? 'Open the disk image and drag <strong>Timbre</strong> onto the Applications folder beside it.'
			: 'Unzip and drag <strong>Timbre.app</strong> to Applications.',
		'Coming from 0.2.0? Replace it, then remove the old Timbre entry under Accessibility and add the new one: 0.3.0 is signed by a renewed developer account. Later updates keep the permission.',
		'Launch it. Timbre lives in the menu bar — there is no dock icon and no window.',
		'Allow <strong>Microphone</strong> when prompted.',
		'Add Timbre under System Settings › Privacy &amp; Security › <strong>Accessibility</strong>. It notices the moment you do.',
		'Click into any text field, hold <strong>right ⌥</strong>, and talk.'
	];
	const colors = ['red', 'orange', 'yellow', 'green', 'blue', 'violet'];
</script>

<svelte:head>
	<title>Download Timbre for macOS</title>
	<meta
		name="description"
		content="Download Timbre, free on-device dictation, read-aloud, text commands and to-dos for macOS 26 on Apple Silicon. Notarized by Apple. No account required."
	/>
</svelte:head>

<section class="mx-auto max-w-3xl px-6 py-16 sm:py-20">
	<p class="eyebrow text-retro-green">Free for personal use</p>
	<h1 class="mt-3 text-5xl sm:text-6xl">Download</h1>
	<p class="text-muted-foreground mt-5 max-w-[58ch] text-lg">
		Notarized by Apple, so it opens without a Gatekeeper warning. Before you download, what it
		needs:
	</p>

	<dl class="mt-8 grid gap-3 sm:grid-cols-3">
		{#each requirements as [name, why, color] (name)}
			<div class="bg-card ring-foreground/8 rounded-xl p-4 ring-1" style="box-shadow: inset 0 -4px 0 0 var(--retro-{color})">
				<dt class="font-semibold">{name}</dt>
				<dd class="text-muted-foreground mt-1.5 text-sm leading-relaxed">{why}</dd>
			</div>
		{/each}
	</dl>

	<div class="bg-card ring-foreground/8 mt-8 rounded-2xl p-6 ring-1 sm:p-8">
		<div class="flex flex-wrap items-center gap-5">
			<Button href={local(dmg ?? release.url)} size="lg" class="h-12 px-6 text-base">
				Download Timbre {release.version}
			</Button>
			<p class="text-muted-foreground font-mono text-xs leading-relaxed">
				{dmg ? 'disk image' : `${megabytes} MB · zip`} · {published}
				{#if dmg}
					· <a href={local(release.url)} class="hover:text-foreground underline underline-offset-4">or the zip</a>
				{/if}
			</p>
		</div>
		<details class="mt-5 text-sm">
			<summary class="cursor-pointer font-medium">What's new in {release.version}</summary>
			<div class="text-muted-foreground mt-3 space-y-1.5">
				{#each notes as line, i (i)}
					{#if line.endsWith(':')}
						<p class="text-foreground mt-3 font-medium first:mt-0">{line.slice(0, -1)}</p>
					{:else}
						<p>{line}</p>
					{/if}
				{/each}
			</div>
		</details>
	</div>

	<h2 class="mt-16 text-3xl">Setting up</h2>
	<ol class="mt-6 space-y-4">
		{#each steps as step, i (i)}
			<li class="flex gap-4">
				<span
					class="mt-0.5 flex size-7 shrink-0 items-center justify-center rounded-md font-mono text-xs font-semibold text-[oklch(0.2_0.005_80)]"
					style="background: var(--retro-{colors[i % colors.length]})"
				>
					{i + 1}
				</span>
				<p class="text-muted-foreground [&_strong]:text-foreground text-[15px] leading-relaxed">{@html step}</p>
			</li>
		{/each}
	</ol>

	<p class="text-muted-foreground mt-8 text-sm leading-relaxed">
		Accessibility is what lets Timbre see the hotkeys while another app is focused, and paste where
		your cursor is. It's the same permission any system-wide text tool needs. Reminders is asked for
		only the first time you say a to-do.
	</p>

	<h2 class="mt-16 text-3xl">Staying up to date</h2>
	<p class="text-muted-foreground mt-4 leading-relaxed">
		Choose <strong class="text-foreground">Check for Updates…</strong> in Timbre's menu, or turn on a
		daily check in Settings — it's off until you do. Timbre installs an update only after checking
		that it's Timbre, signed by its developer and notarized by Apple.
		<a href="/network" class="decoration-retro-green text-foreground underline decoration-2 underline-offset-4">What the check sends</a>: nothing
		about you.
	</p>

	<Stripe height="5px" width="4rem" class="mt-16" />
	<h2 class="mt-5 text-3xl">The three keys</h2>
	<div class="mt-8 grid gap-8 sm:grid-cols-3">
		<div class="flex flex-col items-start gap-4">
			<KeyCap symbol="⌥" name="right option" gesture="hold" color="green" />
			<p class="text-muted-foreground text-sm leading-relaxed">Hold and talk. Release, and the cleaned-up text is pasted where your cursor is.</p>
		</div>
		<div class="flex flex-col items-start gap-4">
			<KeyCap symbol="⌥" name="left option" gesture="tap" color="yellow" />
			<p class="text-muted-foreground text-sm leading-relaxed">Tap with text selected to hear it. Tap again for faster; hold to stop. Nothing selected? It reads your to-dos.</p>
		</div>
		<div class="flex flex-col items-start gap-4">
			<KeyCap symbol="⌘" name="right command" gesture="hold" color="orange" />
			<p class="text-muted-foreground text-sm leading-relaxed">Hold with text selected and say fix, explain, shorten or plain. Nothing selected? Say a to-do.</p>
		</div>
	</div>
</section>
