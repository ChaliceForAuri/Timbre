import { error } from '@sveltejs/kit';
import { fragmentFor, modules } from '$lib/university';
import type { PageLoad } from './$types';

export const load: PageLoad = ({ params }) => {
	const index = modules.findIndex((m) => m.slug === params.slug);
	const fragment = fragmentFor(params.slug);
	if (index === -1 || !fragment) error(404, 'No such module');

	return {
		module: modules[index],
		fragment,
		previous: modules[index - 1] ?? null,
		next: modules[index + 1] ?? null
	};
};
