<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import KeyCap from '$lib/components/marketing/KeyCap.svelte';
	// The same file the app's update check reads, written by tools/release.sh:
	// the download button can never point at a different version.
	import appcast from '../../../../static/appcast.json';

	const release = appcast.latest;
	const megabytes = (release.size / 1_000_000).toFixed(1);
	const published = new Intl.DateTimeFormat('en-GB', { dateStyle: 'long' }).format(
		new Date(`${release.published}T12:00:00`)
	);
	const notes = release.notes
		.split('\n')
		.map((line) => line.trim())
		.filter(Boolean);

	const requirements = [
		['macOS 26 or later', 'Timbre uses SpeechAnalyzer and Foundation Models, both introduced in macOS 26.'],
		['Apple Silicon', 'The speech and language models run on the Neural Engine.'],
		[
			'Apple Intelligence enabled',
			'Without it, dictation and read-aloud still work; the cleanup pass and the text commands need the on-device model.'
		]
	];
</script>

<svelte:head>
	<title>Download Timbre for macOS</title>
	<meta
		name="description"
		content="Download Timbre, free on-device dictation, read-aloud and text commands for macOS 26 on Apple Silicon. Notarized by Apple. No account required."
	/>
</svelte:head>

<section class="mx-auto max-w-3xl px-6 py-20">
	<h1 class="text-4xl">Download</h1>
	<p class="text-muted-foreground mt-4 max-w-[58ch]">
		Free for personal use. Notarized by Apple, so it opens without a Gatekeeper warning. Before
		you download, what it needs:
	</p>

	<dl class="mt-6 space-y-3">
		{#each requirements as [name, why] (name)}
			<div class="bg-card rounded-xl border p-4">
				<dt class="font-sans font-semibold">{name}</dt>
				<dd class="text-muted-foreground mt-1 text-sm">{why}</dd>
			</div>
		{/each}
	</dl>

	<div class="mt-8 flex flex-wrap items-center gap-4">
		<Button href={release.url.replace('https://timbre.hugopretorius.dev', '')} size="lg">
			Download Timbre {release.version}
		</Button>
		<p class="text-muted-foreground font-mono text-xs">
			{megabytes} MB · zip · {published}
		</p>
	</div>

	<details class="bg-card mt-6 rounded-xl border p-4 text-sm">
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

	<h2 class="mt-16 text-2xl">Setting up</h2>
	<ol class="text-muted-foreground mt-5 list-decimal space-y-2.5 pl-5 text-sm">
		<li>Unzip and drag <strong class="text-foreground">Timbre.app</strong> to Applications.</li>
		<li>
			Coming from 0.2.0? Replace it, then remove the old Timbre entry under Accessibility and add the
			new one: 0.3.0 is signed by a renewed developer account. Later updates keep the permission.
		</li>
		<li>Launch it. Timbre lives in the menu bar — there's no dock icon and no window.</li>
		<li>Allow <strong class="text-foreground">Microphone</strong> when prompted.</li>
		<li>
			Add Timbre under System Settings › Privacy &amp; Security ›
			<strong class="text-foreground">Accessibility</strong>. It notices the moment you do.
		</li>
		<li>Click into any text field, hold <strong class="text-foreground">right ⌥</strong>, and talk.</li>
	</ol>

	<p class="text-muted-foreground mt-8 text-sm">
		Accessibility is what lets Timbre see the hotkeys while another app is focused, and paste where
		your cursor is. It's the same permission any system-wide text tool needs.
	</p>

	<h2 class="mt-16 text-2xl">Staying up to date</h2>
	<p class="text-muted-foreground mt-4 text-sm">
		Choose <strong class="text-foreground">Check for Updates…</strong> in Timbre's menu, or turn on a
		daily check in Settings — it's off until you do. Timbre installs an update only after checking
		that it's Timbre, signed by its developer and notarized by Apple.
		<a href="/network" class="text-primary underline underline-offset-4">What the check sends</a>: nothing
		about you.
	</p>

	<h2 class="mt-16 text-2xl">The three keys</h2>
	<div class="mt-8 grid gap-8 sm:grid-cols-3">
		<div class="flex flex-col items-start gap-4">
			<KeyCap symbol="⌥" name="right option" gesture="hold" />
			<p class="text-muted-foreground text-sm">Hold and talk. Release, and the cleaned-up text is pasted where your cursor is.</p>
		</div>
		<div class="flex flex-col items-start gap-4">
			<KeyCap symbol="⌥" name="left option" gesture="tap" />
			<p class="text-muted-foreground text-sm">Tap with text selected to hear it. Tap again for faster; hold to stop.</p>
		</div>
		<div class="flex flex-col items-start gap-4">
			<KeyCap symbol="⌘" name="right command" gesture="hold" />
			<p class="text-muted-foreground text-sm">Hold with text selected and say fix, explain, shorten or plain. Say nothing to fix.</p>
		</div>
	</div>
</section>
