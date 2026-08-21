<script lang="ts">
	import { modules } from '$lib/university';
	import { page } from '$app/state';

	let { children } = $props();
</script>

<div class="mx-auto flex max-w-6xl gap-10 px-6 py-10">
	<aside class="hidden w-64 shrink-0 md:block">
		<nav class="sticky top-8">
			<p class="mb-3 text-xs font-medium uppercase tracking-wider text-muted">
				Timbre University
			</p>
			<ul class="space-y-1 border-l border-line text-sm">
				{#each modules as m (m.slug)}
					{@const active = page.params.slug === m.slug}
					<li>
						<a
							href="/university/{m.slug}"
							class="-ml-px flex gap-2 border-l py-1 pl-4 hover:text-ink
								{active
								? 'border-accent font-medium text-accent-ink'
								: 'border-transparent text-muted'}"
						>
							<span class="w-5 shrink-0 text-right tabular-nums">{m.number}</span>
							<span>{m.title}</span>
						</a>
					</li>
				{/each}
			</ul>
		</nav>
	</aside>
	<div class="min-w-0 flex-1">
		{@render children()}
	</div>
</div>
