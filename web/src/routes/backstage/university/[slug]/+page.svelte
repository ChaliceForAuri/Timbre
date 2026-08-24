<script lang="ts">
	let { data } = $props();
</script>

<svelte:head>
	<title>{data.module.number} · {data.module.title} — Timbre University</title>
</svelte:head>

<article>
	<p class="text-xs font-medium uppercase tracking-wider text-accent">
		Module {data.module.number}
	</p>
	<h1 class="mt-1 mb-8 text-3xl font-semibold tracking-tight text-balance">
		{data.module.title}
	</h1>

	<!-- eslint-disable-next-line svelte/no-at-html-tags -- our own extracted, static content -->
	<div class="university-prose">{@html data.fragment}</div>

	<nav class="mt-14 flex justify-between border-t border-line pt-6 text-sm">
		{#if data.previous}
			<a href="/backstage/university/{data.previous.slug}" class="text-muted hover:text-ink">
				← {data.previous.number} · {data.previous.title}
			</a>
		{:else}<span></span>{/if}
		{#if data.next}
			<a href="/backstage/university/{data.next.slug}" class="text-accent-ink hover:underline">
				{data.next.number} · {data.next.title} →
			</a>
		{/if}
	</nav>
</article>
