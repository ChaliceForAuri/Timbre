/// Who may enter Backstage.
///
/// An allowlist rather than a role column, because there is exactly one
/// person and a database row that grants admin access is a database row that
/// can be changed. Adding people later means moving this to a table; until
/// then the smallest possible surface is the safest one.
export const BACKSTAGE_ALLOWLIST = ['ohheyhugo@gmail.com'] as const;

export function isAllowed(email: string | undefined | null): boolean {
	if (!email) return false;
	return BACKSTAGE_ALLOWLIST.includes(email.toLowerCase().trim() as never);
}
