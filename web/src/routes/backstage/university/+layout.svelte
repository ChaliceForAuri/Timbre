<script lang="ts">
	let { children } = $props();
</script>

<!-- Module navigation moved into the Backstage sidebar, where it unfolds
     under the University item. This layout only sets the reading width. -->
<div class="mx-auto max-w-3xl">
	{@render children()}
</div>
