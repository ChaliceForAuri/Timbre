import { redirect } from '@sveltejs/kit';
import { modules } from '$lib/university';

export function load(): never {
	redirect(307, `/backstage/university/${modules[0].slug}`);
}
