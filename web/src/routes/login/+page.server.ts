import { fail, redirect } from '@sveltejs/kit';
import { isAllowed } from '$lib/auth';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = ({ locals, url }) => {
	if (locals.user && isAllowed(locals.user.email)) redirect(303, '/backstage');
	return {
		denied: url.searchParams.get('denied') === '1',
		signedInAs: locals.user?.email ?? null
	};
};

export const actions: Actions = {
	default: async ({ request, locals, url }) => {
		const data = await request.formData();
		const email = String(data.get('email') ?? '').trim();

		if (!email.includes('@')) {
			return fail(400, { email, message: "That doesn't look like an email address." });
		}

		// Refuse before sending rather than after: mailing a working link to
		// someone who will be turned away at the door is worse than a plain no.
		if (!isAllowed(email)) {
			return fail(403, { email, message: 'That address is not on the Backstage allowlist.' });
		}

		const next = url.searchParams.get('next') ?? '/backstage';
		const { error } = await locals.supabase.auth.signInWithOtp({
			email,
			options: { emailRedirectTo: `${url.origin}/auth/callback?next=${encodeURIComponent(next)}` }
		});

		if (error) return fail(500, { email, message: error.message });
		return { sent: true, email };
	}
};
