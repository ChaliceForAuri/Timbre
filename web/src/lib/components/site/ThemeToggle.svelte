<script lang="ts">
	import { theme } from '$lib/theme.svelte';
	import Sun from '@lucide/svelte/icons/sun';
	import Moon from '@lucide/svelte/icons/moon';

	let { class: className = '' }: { class?: string } = $props();
</script>

<button
	type="button"
	onclick={() => theme.toggle()}
	class="text-muted-foreground hover:text-foreground hover:bg-accent inline-flex size-9 items-center justify-center rounded-md transition-colors {className}"
	aria-label={theme.dark ? 'Switch to light' : 'Switch to dark'}
	title={theme.dark ? 'Light' : 'Dark'}
>
	{#if theme.dark}
		<Sun class="size-4" />
	{:else}
		<Moon class="size-4" />
	{/if}
</button>
