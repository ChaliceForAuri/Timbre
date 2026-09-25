<script lang="ts">
	import { page } from '$app/state';
	import * as Sidebar from '$lib/components/ui/sidebar';
	import * as Breadcrumb from '$lib/components/ui/breadcrumb';
	import { Separator } from '$lib/components/ui/separator';
	import { Button } from '$lib/components/ui/button';
	import CommandPalette from '$lib/components/backstage/CommandPalette.svelte';
	import ThemeToggle from '$lib/components/site/ThemeToggle.svelte';
	import Mark from '$lib/components/marketing/Mark.svelte';
	import Stripe from '$lib/components/marketing/Stripe.svelte';
	import { modules } from '$lib/university';
	import { releases } from '$lib/releases';
	import LayoutDashboard from '@lucide/svelte/icons/layout-dashboard';
	import GraduationCap from '@lucide/svelte/icons/graduation-cap';
	import ChartLine from '@lucide/svelte/icons/chart-line';
	import MessageSquare from '@lucide/svelte/icons/message-square';
	import FlaskConical from '@lucide/svelte/icons/flask-conical';
	import Users from '@lucide/svelte/icons/users';
	import Scale from '@lucide/svelte/icons/scale';
	import ListChecks from '@lucide/svelte/icons/list-checks';
	import Package from '@lucide/svelte/icons/package';
	import Megaphone from '@lucide/svelte/icons/megaphone';
	import Activity from '@lucide/svelte/icons/activity';
	import Search from '@lucide/svelte/icons/search';
	import LogOut from '@lucide/svelte/icons/log-out';
	import ExternalLink from '@lucide/svelte/icons/external-link';

	let { children, data } = $props();

	const path = $derived(page.url.pathname);
	const inUniversity = $derived(path.startsWith('/backstage/university'));
	const currentModule = $derived(modules.find((m) => m.slug === page.params.slug));
	const latest = releases.find((r) => !r.unreleased);

	let paletteOpen = $state(false);

	// The rooms. Each carries the colour of its keycap, so the rail reads
	// as the rainbow at a glance and each page's accent matches its row.
	const live = [
		{ href: '/backstage', label: 'Overview', icon: LayoutDashboard, exact: true, color: 'red' },
		{ href: '/backstage/releases', label: 'Releases', icon: Package, exact: false, color: 'orange' },
		{ href: '/backstage/decisions', label: 'Decisions', icon: Scale, exact: false, color: 'yellow' },
		{ href: '/backstage/plans', label: 'Plans', icon: ListChecks, exact: false, color: 'green' },
		{ href: '/backstage/launch', label: 'Launch', icon: Megaphone, exact: false, color: 'blue' },
		{ href: '/backstage/evals', label: 'Evals', icon: ChartLine, exact: false, color: 'violet' },
		{ href: '/backstage/university', label: 'University', icon: GraduationCap, exact: false, color: 'red' }
	];

	// Breadcrumb: Backstage › section › leaf. A section is any live item
	// below the overview; the leaf is whatever the section's page has open.
	const section = $derived(live.find((item) => !item.exact && path.startsWith(item.href)));
	const leaf = $derived(
		currentModule
			? `${currentModule.number} · ${currentModule.title}`
			: path.startsWith('/backstage/decisions') && page.params.id
				? page.params.id.toUpperCase()
				: undefined
	);

	// From docs/design/backstage.md §13. Shown so the shape of the lab is
	// visible before the rooms exist; disabled so nothing pretends to work.
	const planned = [
		{ label: 'Traces', icon: Activity, phase: '3' },
		{ label: 'Lab', icon: FlaskConical, phase: '4' },
		{ label: 'Feedback', icon: MessageSquare, phase: '5' },
		{ label: 'Customers', icon: Users, phase: '6' }
	];

	const isActive = (href: string, exact: boolean) =>
		exact ? path === href : path.startsWith(href);
</script>

<Sidebar.Provider>
	<Sidebar.Root collapsible="icon">
		<Sidebar.Header>
			<a href="/backstage" class="flex items-center gap-2.5 px-2 py-1.5">
				<Mark size={28} class="shrink-0" />
				<span class="flex flex-col group-data-[collapsible=icon]:hidden">
					<span class="display text-base leading-none">Timbre</span>
					<span class="eyebrow text-muted-foreground mt-1 text-[9px]">backstage</span>
				</span>
				{#if latest}
					<span class="text-muted-foreground ml-auto font-mono text-[10px] group-data-[collapsible=icon]:hidden">
						v{latest.version}
					</span>
				{/if}
			</a>
		</Sidebar.Header>

		<Sidebar.Content>
			<Sidebar.Group>
				<Sidebar.GroupContent>
					<Sidebar.Menu>
						<Sidebar.MenuItem>
							<Sidebar.MenuButton tooltipContent="Search (⌘K)" onclick={() => (paletteOpen = true)}>
								<Search />
								<span class="text-muted-foreground">Search…</span>
								<kbd class="text-muted-foreground ml-auto font-mono text-[10px] group-data-[collapsible=icon]:hidden">⌘K</kbd>
							</Sidebar.MenuButton>
						</Sidebar.MenuItem>
					</Sidebar.Menu>
				</Sidebar.GroupContent>
			</Sidebar.Group>

			<Sidebar.Group>
				<Sidebar.GroupLabel>Rooms</Sidebar.GroupLabel>
				<Sidebar.GroupContent>
					<Sidebar.Menu>
						{#each live as item (item.href)}
							{@const Icon = item.icon}
							<Sidebar.MenuItem>
								<Sidebar.MenuButton isActive={isActive(item.href, item.exact)} tooltipContent={item.label}>
									{#snippet child({ props })}
										<a href={item.href} {...props}>
											<Icon />
											<span>{item.label}</span>
											<span
												class="ml-auto size-1.5 rounded-full opacity-0 transition-opacity group-data-[collapsible=icon]:hidden {isActive(item.href, item.exact) ? 'opacity-100' : ''}"
												style="background: var(--retro-{item.color})"
											></span>
										</a>
									{/snippet}
								</Sidebar.MenuButton>

								<!-- While you're inside the University, the modules unfold
								     beneath it so the curriculum has shape. Leave the section
								     and it folds back to one row. -->
								{#if item.href === '/backstage/university' && inUniversity}
									<Sidebar.MenuSub>
										{#each modules as m (m.slug)}
											<Sidebar.MenuSubItem>
												<Sidebar.MenuSubButton isActive={page.params.slug === m.slug}>
													{#snippet child({ props })}
														<a href="/backstage/university/{m.slug}" {...props}>
															<span class="text-muted-foreground w-4 shrink-0 text-right font-mono text-[11px] tabular-nums">
																{m.number}
															</span>
															<span>{m.title}</span>
														</a>
													{/snippet}
												</Sidebar.MenuSubButton>
											</Sidebar.MenuSubItem>
										{/each}
									</Sidebar.MenuSub>
								{/if}
							</Sidebar.MenuItem>
						{/each}
					</Sidebar.Menu>
				</Sidebar.GroupContent>
			</Sidebar.Group>

			<Sidebar.Group>
				<Sidebar.GroupLabel>Planned</Sidebar.GroupLabel>
				<Sidebar.GroupContent>
					<Sidebar.Menu>
						{#each planned as item (item.label)}
							{@const Icon = item.icon}
							<Sidebar.MenuItem>
								<Sidebar.MenuButton tooltipContent="{item.label} — phase {item.phase}">
									{#snippet child({ props })}
										<span {...props} aria-disabled="true" class="{props.class} cursor-default opacity-60">
											<Icon />
											<span>{item.label}</span>
										</span>
									{/snippet}
								</Sidebar.MenuButton>
								<Sidebar.MenuBadge class="text-muted-foreground font-mono text-[10px]">
									p{item.phase}
								</Sidebar.MenuBadge>
							</Sidebar.MenuItem>
						{/each}
					</Sidebar.Menu>
				</Sidebar.GroupContent>
			</Sidebar.Group>

			<Sidebar.Group class="mt-auto">
				<Sidebar.GroupContent>
					<Sidebar.Menu>
						<Sidebar.MenuItem>
							<Sidebar.MenuButton tooltipContent="The public site">
								{#snippet child({ props })}
									<a href="/" {...props}>
										<ExternalLink />
										<span>The site</span>
									</a>
								{/snippet}
							</Sidebar.MenuButton>
						</Sidebar.MenuItem>
					</Sidebar.Menu>
				</Sidebar.GroupContent>
			</Sidebar.Group>
		</Sidebar.Content>

		<Sidebar.Footer>
			<Sidebar.Menu>
				<Sidebar.MenuItem>
					<form method="POST" action="/logout">
						<Sidebar.MenuButton tooltipContent="Sign out">
							{#snippet child({ props })}
								<button type="submit" {...props}>
									<LogOut />
									<span class="truncate">{data.user?.email ?? 'Sign out'}</span>
								</button>
							{/snippet}
						</Sidebar.MenuButton>
					</form>
				</Sidebar.MenuItem>
			</Sidebar.Menu>
		</Sidebar.Footer>
		<Sidebar.Rail />
	</Sidebar.Root>

	<Sidebar.Inset>
		<!-- Sticky: in a long module the breadcrumb is the way back out. -->
		<header class="bg-background/85 sticky top-0 z-10 flex h-14 shrink-0 items-center gap-2 border-b px-4 backdrop-blur-md">
			<Sidebar.Trigger class="-ml-1" />
			<Separator orientation="vertical" class="mr-2 h-4" />
			<Breadcrumb.Root>
				<Breadcrumb.List>
					<Breadcrumb.Item>
						{#if section}
							<Breadcrumb.Link href="/backstage">Backstage</Breadcrumb.Link>
						{:else}
							<Breadcrumb.Page>Backstage</Breadcrumb.Page>
						{/if}
					</Breadcrumb.Item>
					{#if section}
						<Breadcrumb.Separator />
						<Breadcrumb.Item>
							{#if leaf}
								<Breadcrumb.Link href={section.href}>{section.label}</Breadcrumb.Link>
							{:else}
								<Breadcrumb.Page>{section.label}</Breadcrumb.Page>
							{/if}
						</Breadcrumb.Item>
					{/if}
					{#if leaf}
						<Breadcrumb.Separator />
						<Breadcrumb.Item>
							<Breadcrumb.Page>{leaf}</Breadcrumb.Page>
						</Breadcrumb.Item>
					{/if}
				</Breadcrumb.List>
			</Breadcrumb.Root>

			<div class="ml-auto flex items-center gap-1">
				<Button variant="outline" size="sm" class="text-muted-foreground hidden h-8 gap-2 font-normal sm:inline-flex" onclick={() => (paletteOpen = true)}>
					<Search class="size-3.5" />
					Search
					<kbd class="bg-muted ml-1 rounded px-1.5 py-0.5 font-mono text-[10px]">⌘K</kbd>
				</Button>
				<ThemeToggle />
			</div>
		</header>
		<Stripe height="3px" rounded={false} />

		<div class="flex-1 p-6 md:p-8">
			{@render children()}
		</div>
	</Sidebar.Inset>
</Sidebar.Provider>

<CommandPalette bind:open={paletteOpen} />
