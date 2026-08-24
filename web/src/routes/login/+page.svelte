<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import * as Card from '$lib/components/ui/card';
	import { enhance } from '$app/forms';

	let { data, form } = $props();
</script>

<svelte:head>
	<title>Sign in — Timbre Backstage</title>
	<meta name="robots" content="noindex" />
</svelte:head>

<div class="mx-auto flex min-h-[70vh] max-w-md items-center px-6">
	<Card.Root class="w-full">
		<Card.Header>
			<Card.Title class="text-2xl">Backstage</Card.Title>
			<Card.Description>
				The laboratory: evals, traces, feedback, and the University. Private.
			</Card.Description>
		</Card.Header>

		<Card.Content>
			{#if form?.sent}
				<p class="text-sm">
					Check <strong>{form.email}</strong> — the sign-in link is on its way. It expires shortly,
					so use it soon.
				</p>
			{:else}
				<form method="POST" use:enhance class="flex flex-col gap-3">
					{#if data.denied}
						<p class="text-destructive text-sm">
							{#if data.signedInAs}
								Signed in as {data.signedInAs}, which isn't on the allowlist.
							{:else}
								That account isn't on the Backstage allowlist.
							{/if}
						</p>
					{/if}

					<label class="text-sm font-medium" for="email">Email</label>
					<input
						id="email"
						name="email"
						type="email"
						autocomplete="email"
						required
						value={form?.email ?? ''}
						placeholder="you@example.com"
						class="border-input bg-background ring-offset-background focus-visible:ring-ring h-10 rounded-md border px-3 text-sm focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none"
					/>

					{#if form?.message}
						<p class="text-destructive text-sm">{form.message}</p>
					{/if}

					<Button type="submit" class="mt-1">Email me a sign-in link</Button>
					<p class="text-muted-foreground text-xs">
						No password. The link signs you in once and sets a session.
					</p>
				</form>
			{/if}
		</Card.Content>
	</Card.Root>
</div>
