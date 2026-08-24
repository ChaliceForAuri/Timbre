import { env } from '$env/dynamic/private';

/// Who may enter Backstage.
///
/// Read from the environment rather than committed, for two reasons: a public
/// repository shouldn't advertise a personal address to scrapers, and adding
/// someone shouldn't require a deploy.
///
/// **Fails closed.** With no `BACKSTAGE_ALLOWLIST` set, nobody is allowed —
/// including in a misconfigured production deploy. An auth check that defaults
/// to "let them in" is not an auth check.
export function isAllowed(email: string | undefined | null): boolean {
	if (!email) return false;

	const allowed = (env.BACKSTAGE_ALLOWLIST ?? '')
		.split(',')
		.map((entry) => entry.trim().toLowerCase())
		.filter(Boolean);

	return allowed.includes(email.trim().toLowerCase());
}
