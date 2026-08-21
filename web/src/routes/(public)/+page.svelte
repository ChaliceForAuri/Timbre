<svelte:head>
	<title>Timbre — free, on-device dictation for macOS</title>
	<meta
		name="description"
		content="Hold a key, speak, release. Cleaned-up text appears wherever you're typing. Runs entirely on your Mac."
	/>
</svelte:head>

<section class="mx-auto max-w-3xl px-6 py-24">
	<h1 class="text-4xl font-semibold tracking-tight text-balance">
		Dictation that never leaves your Mac.
	</h1>
	<p class="mt-4 max-w-[60ch] text-lg text-muted">
		Hold right&nbsp;Option, speak, release — cleaned-up text lands in whatever app you're using.
		Transcription and cleanup run entirely on-device with Apple's models. No account, no
		subscription, and the app makes <strong class="text-ink">zero network requests</strong> — check
		it yourself with Little Snitch.
	</p>
	<div class="mt-8 flex gap-4">
		<a
			href="/download"
			class="rounded-lg bg-accent px-5 py-2.5 text-sm font-medium text-paper hover:opacity-90"
		>
			Download
		</a>
		<a
			href="/university"
			class="rounded-lg border border-line px-5 py-2.5 text-sm font-medium hover:border-muted"
		>
			Read how it's built
		</a>
	</div>
	<dl class="mt-20 grid gap-8 sm:grid-cols-3 text-sm">
		<div>
			<dt class="font-medium">On-device, provably</dt>
			<dd class="mt-1 text-muted">
				Speech and language models run on the Neural Engine. Nothing to upload means nothing to
				leak.
			</dd>
		</div>
		<div>
			<dt class="font-medium">It writes, you talk</dt>
			<dd class="mt-1 text-muted">
				Fillers removed, punctuation added, your voice kept. The cleanup is measured against a
				fixed corpus, not vibes.
			</dd>
		</div>
		<div>
			<dt class="font-medium">Built in the open</dt>
			<dd class="mt-1 text-muted">
				The University documents every layer — from audio buffers to eval harnesses — as it was
				learned.
			</dd>
		</div>
	</dl>
</section>
