<script lang="ts">
	/// The rainbow: six hard-edged stripes. The brand's one flourish, used
	/// under the wordmark, between sections and along the footer.
	let {
		height = '4px',
		width = '100%',
		rounded = true,
		class: className = ''
	}: { height?: string; width?: string; rounded?: boolean; class?: string } = $props();
</script>

<span
	class="rainbow block {rounded ? 'rounded-full' : ''} {className}"
	style="height: {height}; width: {width};"
	aria-hidden="true"
></span>
