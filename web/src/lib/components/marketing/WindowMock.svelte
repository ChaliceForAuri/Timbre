<script lang="ts">
	import type { Snippet } from 'svelte';

	/// A generic Mac window: the frame the pill floats over. Deliberately not
	/// a specific app — the point is "any app", and a fake Slack would age.
	let { title, children, class: className = '' }: { title: string; children: Snippet; class?: string } =
		$props();
</script>

<div class="bg-card overflow-hidden rounded-xl border shadow-[0_24px_48px_-24px_rgb(0_0_0/0.45)] {className}">
	<div class="bg-secondary/60 flex items-center gap-2 border-b px-3 py-2">
		<span class="flex gap-1.5" aria-hidden="true">
			<span class="size-2.5 rounded-full bg-[#ff5f57]"></span>
			<span class="size-2.5 rounded-full bg-[#febc2e]"></span>
			<span class="size-2.5 rounded-full bg-[#28c840]"></span>
		</span>
		<span class="text-muted-foreground ml-1 truncate text-xs">{title}</span>
	</div>
	<div class="p-4 text-[13.5px] leading-relaxed">
		{@render children()}
	</div>
</div>
