<script lang="ts">
	import { Button } from '$lib/components/ui/button';

	const requirements = [
		['macOS 26 or later', 'Timbre uses SpeechAnalyzer and Foundation Models, both introduced in macOS 26.'],
		['Apple Silicon', 'The speech and language models run on the Neural Engine.'],
		['Apple Intelligence enabled', 'Without it the cleanup step is skipped and you get the raw transcript.']
	];
</script>

<svelte:head>
	<title>Download Timbre for macOS</title>
	<meta
		name="description"
		content="Download Timbre, free on-device dictation and read-aloud for macOS 26 on Apple Silicon. Notarized by Apple. No account required."
	/>
</svelte:head>

<section class="mx-auto max-w-3xl px-6 py-20">
	<h1 class="text-4xl">Download</h1>
	<p class="text-muted-foreground mt-4 max-w-[58ch]">
		Free for personal use. Notarized by Apple, so it opens without a Gatekeeper warning.
	</p>

	<div class="mt-8">
		<Button href="https://github.com/ChaliceForAuri/Timbre/releases/latest" size="lg">
			Get the latest release
		</Button>
	</div>

	<h2 class="mt-16 text-2xl">Requirements</h2>
	<dl class="mt-5 space-y-4">
		{#each requirements as [name, why] (name)}
			<div>
				<dt class="font-sans font-semibold">{name}</dt>
				<dd class="text-muted-foreground mt-1 text-sm">{why}</dd>
			</div>
		{/each}
	</dl>

	<h2 class="mt-14 text-2xl">Setting up</h2>
	<ol class="text-muted-foreground mt-5 list-decimal space-y-2.5 pl-5 text-sm">
		<li>Unzip and drag <strong class="text-foreground">Timbre.app</strong> to Applications.</li>
		<li>Launch it. Timbre lives in the menu bar — there's no dock icon and no window.</li>
		<li>Allow <strong class="text-foreground">Microphone</strong> when prompted.</li>
		<li>
			Add Timbre under System Settings › Privacy &amp; Security ›
			<strong class="text-foreground">Accessibility</strong>. It notices the moment you do.
		</li>
		<li>Click into any text field, hold <strong class="text-foreground">right ⌥</strong>, and talk.</li>
	</ol>

	<p class="text-muted-foreground mt-8 text-sm">
		Accessibility is what lets Timbre see the hotkey while another app is focused, and paste where
		your cursor is. It's the same permission any system-wide text tool needs.
	</p>
</section>
