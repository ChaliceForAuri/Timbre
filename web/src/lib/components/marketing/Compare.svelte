<script lang="ts">
	/// Factual, from each product's own pages as of September 2026. Every cell
	/// is something a reader can check; nothing here is an opinion.
	type Cell = 'yes' | 'no' | string;
	const columns = ['Timbre', 'macOS Dictation', 'Wispr Flow', 'Tidy'];
	const rows: { feature: string; cells: Cell[] }[] = [
		{ feature: 'Dictate into any app', cells: ['yes', 'yes', 'yes', 'no'] },
		{ feature: 'Cleans up filler and punctuation', cells: ['on-device', 'no', 'in the cloud', 'no'] },
		{ feature: 'Fixes text you select', cells: ['yes', 'no', 'no', 'yes'] },
		{ feature: 'Shortens or de-slops a selection', cells: ['yes', 'no', 'no', 'yes'] },
		{ feature: 'Explains a selection, using your own definitions', cells: ['yes', 'no', 'no', 'no'] },
		{ feature: 'Reads text aloud', cells: ['yes', 'Spoken Content', 'no', 'no'] },
		{ feature: 'To-dos by voice, into Reminders', cells: ['yes', 'via Siri', 'no', 'no'] },
		{ feature: 'Learns your words and corrections', cells: ['yes', 'partly', 'yes', 'no'] },
		{ feature: 'Where your voice goes', cells: ['nowhere', 'on-device for most languages', 'their servers', 'no voice'] },
		{ feature: 'Network requests', cells: ['none by default', 'none for on-device languages', 'yes', 'its update feed'] },
		{ feature: 'Account', cells: ['none', 'none', 'required', 'none'] },
		{ feature: 'Price', cells: ['free', 'included', 'subscription', 'free'] },
		{ feature: 'Source', cells: ['open', 'closed', 'closed', 'closed'] }
	];
</script>

<div class="bg-card ring-foreground/8 overflow-x-auto rounded-2xl ring-1">
	<table class="w-full min-w-[680px] border-collapse text-sm">
		<thead>
			<tr class="border-b-2">
				<th class="py-3 pr-4 pl-5 text-left"></th>
				{#each columns as column, i (column)}
					<th class="eyebrow py-3 pr-4 text-left {i === 0 ? 'text-foreground' : 'text-muted-foreground'}">
						{#if i === 0}
							<span class="inline-flex items-center gap-2">
								<span class="rainbow inline-block h-2 w-6 rounded-full"></span>
								{column}
							</span>
						{:else}
							{column}
						{/if}
					</th>
				{/each}
			</tr>
		</thead>
		<tbody>
			{#each rows as row (row.feature)}
				<tr class="border-border/70 border-b last:border-0">
					<td class="py-2.5 pr-4 pl-5 font-medium">{row.feature}</td>
					{#each row.cells as cell, i (i)}
						<td class="py-2.5 pr-4 whitespace-nowrap {i === 0 ? 'text-foreground font-medium' : 'text-muted-foreground'}">
							{#if cell === 'yes'}
								<svg class="size-4 {i === 0 ? 'text-retro-green' : 'text-muted-foreground'}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" aria-label="yes">
									<path d="M5 12.5l4.5 4.5L19 7" />
								</svg>
							{:else if cell === 'no'}
								<span class="text-muted-foreground/50" aria-label="no">—</span>
							{:else}
								{cell}
							{/if}
						</td>
					{/each}
				</tr>
			{/each}
		</tbody>
	</table>
</div>
<p class="text-muted-foreground mt-3 text-xs">
	From each product's own website, September 2026. If something here is wrong, the source is one
	click away and a correction is welcome.
</p>
