import { error } from '@sveltejs/kit';
import { byId } from '$lib/decisions';
import type { PageLoad } from './$types';

export const load: PageLoad = ({ params }) => {
	if (!params.id) return { open: null };
	const open = byId(params.id);
	if (!open) error(404, `No decision record ${params.id}`);
	return { open };
};
