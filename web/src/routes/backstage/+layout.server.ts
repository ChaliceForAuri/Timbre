import type { LayoutServerLoad } from './$types';

/// Backstage is per-user by definition, so it is never prerendered.
/// `hooks.server.ts` has already enforced the allowlist by the time this runs.
export const prerender = false;

export const load: LayoutServerLoad = ({ locals }) => ({ user: locals.user });
