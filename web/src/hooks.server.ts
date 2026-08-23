import { createServerClient } from '@supabase/ssr';
import { type Handle, redirect } from '@sveltejs/kit';
import { building } from '$app/environment';
import { env } from '$env/dynamic/public';
import { isAllowed } from '$lib/auth';

/// Attaches a request-scoped Supabase client and resolves the session once,
/// then guards Backstage.
///
/// The guard lives here rather than in a layout so that every route under
/// /backstage is covered by construction — including ones added later by
/// someone who forgets. A route is protected because of where it lives, not
/// because it remembered to ask.
export const handle: Handle = async ({ event, resolve }) => {
	// Never authenticate during a build. There is no user at build time, and
	// redirecting here let the prerenderer bake a permanent "go to /login"
	// into a static backstage.html — which would have kept redirecting long
	// after auth started working.
	if (building) {
		event.locals.user = null;
		return resolve(event);
	}

	const url = env.PUBLIC_SUPABASE_URL;
	const anonKey = env.PUBLIC_SUPABASE_ANON_KEY;

	// Without credentials there is no auth to do. The public site — which
	// prerenders, and therefore runs this during build — must not depend on
	// Supabase existing, and neither should a fresh clone.
	if (!url || !anonKey) {
		event.locals.user = null;
		if (event.url.pathname.startsWith('/backstage')) {
			redirect(303, '/login?unconfigured=1');
		}
		return resolve(event);
	}

	event.locals.supabase = createServerClient(
		url,
		anonKey,
		{
			cookies: {
				getAll: () => event.cookies.getAll(),
				setAll: (cookiesToSet) => {
					for (const { name, value, options } of cookiesToSet) {
						event.cookies.set(name, value, { ...options, path: '/' });
					}
				}
			}
		}
	);

	// getUser() revalidates against Supabase; getSession() alone trusts a
	// cookie the browser could have forged.
	const {
		data: { user }
	} = await event.locals.supabase.auth.getUser();
	event.locals.user = user ?? null;

	if (event.url.pathname.startsWith('/backstage')) {
		if (!user) {
			redirect(303, `/login?next=${encodeURIComponent(event.url.pathname)}`);
		}
		if (!isAllowed(user.email)) {
			// Signed in as somebody else entirely: say so plainly rather than
			// bouncing them through a login they have already completed.
			redirect(303, '/login?denied=1');
		}
	}

	return resolve(event, {
		filterSerializedResponseHeaders: (name) => name === 'content-range'
	});
};
