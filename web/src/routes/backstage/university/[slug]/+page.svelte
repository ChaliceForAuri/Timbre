<script lang="ts">
	let { data } = $props();
</script>

<svelte:head>
	<title>{data.module.number} · {data.module.title} — Timbre University</title>
</svelte:head>

<article>
	<p class="eyebrow text-retro-red">Module {data.module.number}</p>
	<h1 class="mt-2 mb-8 text-4xl sm:text-5xl">{data.module.title}</h1>

	<!-- eslint-disable-next-line svelte/no-at-html-tags -- our own extracted, static content -->
	<div class="record-prose">{@html data.fragment}</div>

	<nav class="mt-14 flex justify-between gap-6 border-t pt-6 text-sm">
		{#if data.previous}
			<a href="/backstage/university/{data.previous.slug}" class="text-muted-foreground hover:text-foreground">
				← {data.previous.number} · {data.previous.title}
			</a>
		{:else}<span></span>{/if}
		{#if data.next}
			<a href="/backstage/university/{data.next.slug}" class="decoration-retro-green text-right underline decoration-2 underline-offset-4">
				{data.next.number} · {data.next.title} →
			</a>
		{/if}
	</nav>
</article>
