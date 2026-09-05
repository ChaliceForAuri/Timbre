<script lang="ts">
	import { page } from '$app/state';
	import * as Sidebar from '$lib/components/ui/sidebar';
	import * as Breadcrumb from '$lib/components/ui/breadcrumb';
	import { Separator } from '$lib/components/ui/separator';
	import { modules } from '$lib/university';
	import LayoutDashboard from '@lucide/svelte/icons/layout-dashboard';
	import GraduationCap from '@lucide/svelte/icons/graduation-cap';
	import ChartLine from '@lucide/svelte/icons/chart-line';
	import MessageSquare from '@lucide/svelte/icons/message-square';
	import FlaskConical from '@lucide/svelte/icons/flask-conical';
	import Users from '@lucide/svelte/icons/users';
	import LogOut from '@lucide/svelte/icons/log-out';

	let { children, data } = $props();

	const path = $derived(page.url.pathname);
	const inUniversity = $derived(path.startsWith('/backstage/university'));
	const currentModule = $derived(modules.find((m) => m.slug === page.params.slug));

	const live = [
		{ href: '/backstage', label: 'Overview', icon: LayoutDashboard, exact: true },
		{ href: '/backstage/university', label: 'University', icon: GraduationCap, exact: false }
	];

	// From docs/design/backstage.md §13. Shown so the shape of the lab is
	// visible before the rooms exist; disabled so nothing pretends to work.
	const planned = [
		{ label: 'Evals', icon: ChartLine, phase: '2' },
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
			<a href="/backstage" class="flex items-center gap-2 px-2 py-1.5">
				<span
					class="bg-primary text-primary-foreground flex size-7 shrink-0 items-center justify-center rounded-md font-serif text-sm"
				>
					T
				</span>
				<span class="font-serif text-base group-data-[collapsible=icon]:hidden">Timbre</span>
				<span
					class="text-muted-foreground ml-auto font-mono text-[10px] tracking-widest uppercase group-data-[collapsible=icon]:hidden"
				>
					backstage
				</span>
			</a>
		</Sidebar.Header>

		<Sidebar.Content>
			<Sidebar.Group>
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
										</a>
									{/snippet}
								</Sidebar.MenuButton>

								<!-- One menu item, as asked — but while you're inside it,
								     the modules unfold beneath it so the curriculum has
								     shape. Leave the section and it folds back to one row. -->
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
										<span {...props} aria-disabled="true" class="{props.class} cursor-default">
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
		<header class="flex h-14 shrink-0 items-center gap-2 border-b px-4">
			<Sidebar.Trigger class="-ml-1" />
			<Separator orientation="vertical" class="mr-2 h-4" />
			<Breadcrumb.Root>
				<Breadcrumb.List>
					<Breadcrumb.Item>
						{#if path === '/backstage'}
							<Breadcrumb.Page>Backstage</Breadcrumb.Page>
						{:else}
							<Breadcrumb.Link href="/backstage">Backstage</Breadcrumb.Link>
						{/if}
					</Breadcrumb.Item>
					{#if inUniversity}
						<Breadcrumb.Separator />
						<Breadcrumb.Item>
							{#if currentModule}
								<Breadcrumb.Link href="/backstage/university">University</Breadcrumb.Link>
							{:else}
								<Breadcrumb.Page>University</Breadcrumb.Page>
							{/if}
						</Breadcrumb.Item>
					{/if}
					{#if currentModule}
						<Breadcrumb.Separator />
						<Breadcrumb.Item>
							<Breadcrumb.Page>{currentModule.number} · {currentModule.title}</Breadcrumb.Page>
						</Breadcrumb.Item>
					{/if}
				</Breadcrumb.List>
			</Breadcrumb.Root>
		</header>

		<div class="flex-1 p-6 md:p-8">
			{@render children()}
		</div>
	</Sidebar.Inset>
</Sidebar.Provider>
