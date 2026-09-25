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
		{ feature: 'Learns your words and corrections', cells: ['yes', 'partly', 'yes', 'no'] },
		{ feature: 'Where your voice goes', cells: ['nowhere', 'on-device for most languages', 'their servers', 'no voice'] },
		{ feature: 'Network requests', cells: ['none by default', 'none for on-device languages', 'yes', 'its update feed'] },
		{ feature: 'Account', cells: ['none', 'none', 'required', 'none'] },
		{ feature: 'Price', cells: ['free', 'included', 'subscription', 'free'] },
		{ feature: 'Source', cells: ['open', 'closed', 'closed', 'closed'] }
	];
</script>

<div class="overflow-x-auto">
	<table class="w-full min-w-[640px] border-collapse text-sm">
		<thead>
			<tr class="border-b">
				<th class="py-3 pr-4 text-left font-mono text-[11px] font-medium tracking-[0.12em] text-muted-foreground uppercase"></th>
				{#each columns as column, i (column)}
					<th
						class="py-3 pr-4 text-left font-mono text-[11px] font-medium tracking-[0.12em] uppercase {i === 0
							? 'text-primary'
							: 'text-muted-foreground'}"
					>
						{column}
					</th>
				{/each}
			</tr>
		</thead>
		<tbody>
			{#each rows as row (row.feature)}
				<tr class="border-border/60 border-b">
					<td class="py-2.5 pr-4 font-medium">{row.feature}</td>
					{#each row.cells as cell, i (i)}
						<td class="py-2.5 pr-4 whitespace-nowrap {i === 0 ? 'text-foreground' : 'text-muted-foreground'}">
							{#if cell === 'yes'}
								<svg class="text-primary size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-label="yes">
									<path d="M5 12.5l4.5 4.5L19 7" />
								</svg>
							{:else if cell === 'no'}
								<span class="text-muted-foreground/60" aria-label="no">—</span>
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
