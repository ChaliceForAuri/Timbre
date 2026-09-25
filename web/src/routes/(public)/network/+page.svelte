<script lang="ts">
	/// GDR-0013's promise: the headline says "zero network requests", marked,
	/// and the mark leads here — every request the binary can make, what it
	/// carries, and what turns it on. If Timbre ever gains another request,
	/// this page changes in the same pull request, or the request doesn't ship.
	const requests = [
		{
			name: 'Update check',
			when: 'When you choose Check for Updates… in the menu, or once a day if you turn that on in Settings. Off by default.',
			request: 'GET https://timbre.hugopretorius.dev/appcast.json',
			carries:
				'Nothing about you. No identifier, no cookie, no cache. The only header Timbre sets is User-Agent: Timbre.',
			returns: 'The newest version number, its download address, and its release notes.'
		},
		{
			name: 'Update download',
			when: 'Only when you click Install after a check finds a newer version.',
			request: 'GET https://timbre.hugopretorius.dev/releases/Timbre-<version>.zip',
			carries: 'The same: nothing about you.',
			returns:
				'The new app. Before it replaces anything, Timbre checks the file matches the version file and that the app inside is Timbre, signed by its developer and notarized by Apple.'
		}
	];
</script>

<svelte:head>
	<title>Every network request Timbre can make</title>
	<meta
		name="description"
		content="Timbre makes no network requests out of the box. This page lists every request it is capable of making, what each one carries, and what turns it on."
	/>
</svelte:head>

<section class="mx-auto max-w-3xl px-6 py-20">
	<p class="text-primary font-mono text-xs tracking-[0.14em] uppercase">The asterisk</p>
	<h1 class="mt-3 text-4xl">Every network request Timbre can make</h1>
	<p class="text-muted-foreground mt-5 max-w-[62ch] leading-relaxed">
		Out of the box: none. Speech recognition, cleanup, read-aloud and the text commands run on your
		Mac, and nothing you say or write is ever sent anywhere. Below is the complete list of what the
		app is capable of asking the internet for. It has two entries, and both start with you.
	</p>

	<div class="mt-10 space-y-5">
		{#each requests as r (r.name)}
			<article class="bg-card rounded-xl border p-5">
				<h2 class="font-sans text-lg font-semibold">{r.name}</h2>
				<p class="bg-secondary mt-3 overflow-x-auto rounded-md px-3 py-2 font-mono text-xs">
					{r.request}
				</p>
				<dl class="mt-4 grid gap-3 text-sm sm:grid-cols-[8rem_1fr]">
					<dt class="text-muted-foreground font-mono text-[11px] tracking-[0.12em] uppercase">When</dt>
					<dd>{r.when}</dd>
					<dt class="text-muted-foreground font-mono text-[11px] tracking-[0.12em] uppercase">Sends</dt>
					<dd>{r.carries}</dd>
					<dt class="text-muted-foreground font-mono text-[11px] tracking-[0.12em] uppercase">Gets back</dt>
					<dd>{r.returns}</dd>
				</dl>
			</article>
		{/each}
	</div>

	<h2 class="mt-16 text-2xl">What macOS does on Timbre's behalf</h2>
	<p class="text-muted-foreground mt-4 leading-relaxed">
		Two things happen that Timbre starts but does not perform, and a network monitor will show them
		under macOS's own processes rather than Timbre's:
	</p>
	<ul class="text-muted-foreground mt-4 list-disc space-y-2.5 pl-5 text-sm leading-relaxed">
		<li>
			<strong class="text-foreground">Apple's speech model.</strong> The first time Timbre runs,
			macOS may download its on-device speech model for your language, from Apple, through its own
			asset service. Nothing you say is involved; the model is what lets your voice stay on the Mac
			afterwards.
		</li>
		<li>
			<strong class="text-foreground">Gatekeeper.</strong> When you first open any app downloaded
			from the internet, macOS may confirm its notarization with Apple. That is true of every app, and
			the ticket is stapled to Timbre so it can be checked offline too.
		</li>
	</ul>

	<h2 class="mt-16 text-2xl">Check it yourself</h2>
	<p class="text-muted-foreground mt-4 leading-relaxed">
		Run a network monitor such as Little Snitch or LuLu, or watch Terminal while you dictate:
	</p>
	<pre class="bg-secondary mt-4 overflow-x-auto rounded-md px-4 py-3 font-mono text-xs">nettop -p Timbre</pre>
	<p class="text-muted-foreground mt-4 leading-relaxed">
		With update checks off, the list stays empty. The code is
		<a href="https://github.com/ChaliceForAuri/Timbre" class="text-primary underline underline-offset-4"
			>public</a
		>, and the decision behind this page is recorded as GDR-0013. If Timbre ever gains another
		request, it appears here in the same change, or it does not ship.
	</p>
</section>
