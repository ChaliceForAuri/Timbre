import { redirect } from '@sveltejs/kit';
import { isAllowed } from '$lib/server/allowlist';
import type { RequestHandler } from './$types';

/// Exchanges the magic-link code for a session cookie.
export const GET: RequestHandler = async ({ url, locals }) => {
	const code = url.searchParams.get('code');
	const next = url.searchParams.get('next') ?? '/backstage';

	if (!code) redirect(303, '/login');

	const { error } = await locals.supabase.auth.exchangeCodeForSession(code);
	if (error) redirect(303, '/login?denied=1');

	// Re-check at the door. The allowlist is enforced when the link is
	// requested, but a link is a bearer token — verify who actually walked in.
	const {
		data: { user }
	} = await locals.supabase.auth.getUser();
	if (!isAllowed(user?.email)) {
		await locals.supabase.auth.signOut();
		redirect(303, '/login?denied=1');
	}

	redirect(303, next);
};
