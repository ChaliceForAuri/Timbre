<script lang="ts">
	import { Badge } from '$lib/components/ui/badge';
	import { Button } from '$lib/components/ui/button';
	import { releases } from '$lib/releases';
	import appcast from '../../../../static/appcast.json';
	import ExternalLink from '@lucide/svelte/icons/external-link';

	/// Every version, from the changelog, newest first. The one the site
	/// serves gets its appcast details — the same file the app's update
	/// check reads, so this page and the app can never disagree.
	const current = appcast.latest;
	const dmg = (current as { dmgURL?: string }).dmgURL ?? null;
	const longDate = new Intl.DateTimeFormat('en-GB', { dateStyle: 'long' });
	const at = (iso: string) => new Date(`${iso}T12:00:00`);
	const megabytes = (current.size / 1_000_000).toFixed(1);
</script>

<svelte:head>
	<title>Releases — Timbre Backstage</title>
	<meta name="robots" content="noindex" />
</svelte:head>

<p class="eyebrow text-retro-orange">Releases</p>
<h1 class="mt-2 text-4xl sm:text-5xl">What shipped, and what's next.</h1>
<p class="text-muted-foreground mt-3 max-w-[62ch]">
	Read from the changelog: a version's section becomes its release notes in the app, on the
	download page, and here. The Unreleased section is the next release, forming.
</p>

<div class="mt-10 space-y-6">
	{#each releases as release (release.version)}
		{@const isCurrent = release.version === current.version}
		<article
			id={release.version}
			class="bg-card ring-foreground/8 scroll-mt-24 rounded-2xl p-6 ring-1 sm:p-8 {release.unreleased ? 'border-retro-orange border-2 border-dashed ring-0' : ''}"
		>
			<div class="flex flex-wrap items-center gap-3">
				<h2 class="text-3xl">
					{#if release.unreleased}Next{:else}v{release.version}{/if}
				</h2>
				{#if release.unreleased}
					<Badge class="bg-retro-orange text-[oklch(0.2_0.005_80)] hover:bg-retro-orange">forming · {release.items} changes</Badge>
				{:else if isCurrent}
					<Badge class="bg-retro-green text-[oklch(0.2_0.005_80)] hover:bg-retro-green">on the site</Badge>
				{/if}
				{#if release.date}
					<span class="text-muted-foreground font-mono text-xs">{longDate.format(at(release.date))}</span>
				{/if}
				<Button variant="ghost" size="sm" href={release.url} class="text-muted-foreground ml-auto h-8">
					{release.unreleased ? 'CHANGELOG.md' : 'GitHub release'} <ExternalLink class="size-3.5" />
				</Button>
			</div>

			{#if release.intro}
				<p class="text-muted-foreground mt-3 text-sm">{release.intro}</p>
			{/if}

			{#if isCurrent}
				<dl class="bg-secondary/60 mt-5 grid gap-x-6 gap-y-2 rounded-xl p-4 font-mono text-xs sm:grid-cols-[6rem_1fr]">
					<dt class="text-muted-foreground">build</dt>
					<dd>{current.build} · minimum macOS {current.minimumSystemVersion}</dd>
					<dt class="text-muted-foreground">zip</dt>
					<dd class="truncate"><a href={current.url} class="hover:underline">{current.url}</a> · {megabytes} MB</dd>
					{#if dmg}
						<dt class="text-muted-foreground">disk image</dt>
						<dd class="truncate"><a href={dmg} class="hover:underline">{dmg}</a></dd>
					{/if}
					<dt class="text-muted-foreground">sha256</dt>
					<dd class="truncate" title={current.sha256}>{current.sha256}</dd>
				</dl>
			{/if}

			<div class="mt-5 grid gap-6 {release.sections.length > 1 ? 'lg:grid-cols-2' : ''}">
				{#each release.sections as section, i (i)}
					<div>
						<p
							class="eyebrow"
							style="color: var(--retro-{section.name === 'Added' ? 'green' : section.name === 'Fixed' ? 'red' : 'blue'})"
						>
							{section.name}
						</p>
						<div class="record-prose mt-2 text-sm [&_li]:mb-2 [&_ul]:pl-4">{@html section.html}</div>
					</div>
				{/each}
			</div>
		</article>
	{/each}
</div>

<p class="text-muted-foreground mt-8 text-sm">
	To cut a release: bump <code class="font-mono text-xs">MARKETING_VERSION</code>, name the section in the changelog, run
	<code class="font-mono text-xs">tools/release.sh</code>, merge. The script refuses without a changelog section.
</p>
