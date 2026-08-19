import { redirect } from '@sveltejs/kit';
import { modules } from '$lib/university';

export function load(): never {
	redirect(307, `/university/${modules[0].slug}`);
}
