<script lang="ts">
	import { page } from '$app/state';

	let { children } = $props();
</script>

<div class="flex min-h-screen flex-col">
	<header class="border-border/60 border-b">
		<nav class="mx-auto flex max-w-5xl items-center gap-6 px-6 py-4">
			<a href="/" class="font-serif text-lg tracking-tight">Timbre</a>
			<a
				href="/download"
				class="text-muted-foreground hover:text-foreground text-sm"
				class:text-foreground={page.url.pathname.startsWith('/download')}
			>
				Download
			</a>
			<a
				href="/backstage"
				class="text-muted-foreground hover:text-foreground ml-auto text-sm"
				rel="nofollow"
			>
				Backstage
			</a>
		</nav>
	</header>

	<main class="flex-1">
		{@render children()}
	</main>

	<footer class="border-border/60 border-t">
		<div
			class="text-muted-foreground mx-auto flex max-w-5xl flex-wrap gap-x-6 gap-y-2 px-6 py-8 text-xs"
		>
			<span>Timbre never sends your voice or your text off this Mac.</span>
			<a href="https://github.com/ChaliceForAuri/Timbre" class="hover:text-foreground ml-auto">
				Source
			</a>
		</div>
	</footer>
</div>
