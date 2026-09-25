<script lang="ts">
	import { goto } from '$app/navigation';
	import * as Command from '$lib/components/ui/command';
	import { records } from '$lib/decisions';
	import { plans } from '$lib/plans';
	import { releases } from '$lib/releases';
	import { launchDocs } from '$lib/launch';
	import { modules } from '$lib/university';
	import { evals } from '$lib/evals';
	import LayoutDashboard from '@lucide/svelte/icons/layout-dashboard';
	import Package from '@lucide/svelte/icons/package';
	import Scale from '@lucide/svelte/icons/scale';
	import ListChecks from '@lucide/svelte/icons/list-checks';
	import Megaphone from '@lucide/svelte/icons/megaphone';
	import ChartLine from '@lucide/svelte/icons/chart-line';
	import GraduationCap from '@lucide/svelte/icons/graduation-cap';
	import Sun from '@lucide/svelte/icons/sun-moon';
	import { theme } from '$lib/theme.svelte';

	/// ⌘K: everything in Backstage, one search away. Pages, every decision,
	/// every plan, release, launch document, University module and eval
	/// case — all static data, so the index is the site itself.
	let { open = $bindable(false) }: { open?: boolean } = $props();

	const pages = [
		{ label: 'Overview', href: '/backstage', icon: LayoutDashboard },
		{ label: 'Releases', href: '/backstage/releases', icon: Package },
		{ label: 'Decisions', href: '/backstage/decisions', icon: Scale },
		{ label: 'Plans', href: '/backstage/plans', icon: ListChecks },
		{ label: 'Launch', href: '/backstage/launch', icon: Megaphone },
		{ label: 'Evals', href: '/backstage/evals', icon: ChartLine },
		{ label: 'University', href: '/backstage/university', icon: GraduationCap }
	];

	function go(href: string) {
		open = false;
		goto(href);
	}
</script>

<svelte:window
	onkeydown={(event) => {
		if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
			event.preventDefault();
			open = !open;
		}
	}}
/>

<Command.Dialog bind:open title="Search Backstage" description="Pages, decisions, plans, releases, modules and eval cases">
	<Command.Input placeholder="Search Backstage…" />
	<Command.List class="max-h-[60vh]">
		<Command.Empty>Nothing by that name.</Command.Empty>

		<Command.Group heading="Pages">
			{#each pages as page (page.href)}
				{@const Icon = page.icon}
				<Command.Item value="page {page.label}" onSelect={() => go(page.href)}>
					<Icon class="size-4" />
					<span>{page.label}</span>
				</Command.Item>
			{/each}
			<Command.Item value="theme toggle light dark" onSelect={() => { theme.toggle(); open = false; }}>
				<Sun class="size-4" />
				<span>Switch to {theme.dark ? 'light' : 'dark'}</span>
				<Command.Shortcut>theme</Command.Shortcut>
			</Command.Item>
		</Command.Group>

		<Command.Group heading="Decisions">
			{#each records as record (record.id)}
				<Command.Item value="{record.id} {record.title} {record.kind}" onSelect={() => go(`/backstage/decisions/${record.id}`)}>
					<span class="text-muted-foreground w-20 shrink-0 font-mono text-xs">{record.id}</span>
					<span class="truncate">{record.title}</span>
					{#if record.statusKind === 'superseded'}
						<Command.Shortcut>superseded</Command.Shortcut>
					{/if}
				</Command.Item>
			{/each}
		</Command.Group>

		<Command.Group heading="Releases">
			{#each releases as release (release.version)}
				<Command.Item value="release {release.version} {release.date ?? 'next'}" onSelect={() => go(`/backstage/releases#${release.version}`)}>
					<Package class="size-4" />
					<span>{release.unreleased ? 'Next release' : release.version}</span>
					{#if release.date}<Command.Shortcut>{release.date}</Command.Shortcut>{/if}
				</Command.Item>
			{/each}
		</Command.Group>

		<Command.Group heading="Plans and launch">
			{#each plans as plan (plan.slug)}
				<Command.Item value="plan {plan.title}" onSelect={() => go(`/backstage/plans#${plan.slug}`)}>
					<ListChecks class="size-4" />
					<span>{plan.title}</span>
				</Command.Item>
			{/each}
			{#each launchDocs as doc (doc.slug)}
				<Command.Item value="launch {doc.title} {doc.kind}" onSelect={() => go(`/backstage/launch#${doc.slug}`)}>
					<Megaphone class="size-4" />
					<span>{doc.title}</span>
					<Command.Shortcut>{doc.kind}</Command.Shortcut>
				</Command.Item>
			{/each}
		</Command.Group>

		<Command.Group heading="University">
			{#each modules as m (m.slug)}
				<Command.Item value="module {m.number} {m.title}" onSelect={() => go(`/backstage/university/${m.slug}`)}>
					<span class="text-muted-foreground w-6 shrink-0 text-right font-mono text-xs">{m.number}</span>
					<span>{m.title}</span>
				</Command.Item>
			{/each}
		</Command.Group>

		<Command.Group heading="Eval cases">
			{#each evals.polisher.cases as c (c.id)}
				<Command.Item value="polisher case {c.id} {c.note}" onSelect={() => go(`/backstage/evals?case=${c.id}`)}>
					<span class="text-muted-foreground w-20 shrink-0 font-mono text-xs">polisher</span>
					<span class="truncate">{c.id}</span>
				</Command.Item>
			{/each}
			{#each evals.commands.cases as c (c.id)}
				<Command.Item value="command case {c.id} {c.command} {c.note}" onSelect={() => go(`/backstage/evals?case=${c.id}`)}>
					<span class="text-muted-foreground w-20 shrink-0 font-mono text-xs">{c.command}</span>
					<span class="truncate">{c.id}</span>
				</Command.Item>
			{/each}
		</Command.Group>
	</Command.List>
</Command.Dialog>
