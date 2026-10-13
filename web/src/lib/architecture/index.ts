/// The perspectives the Architecture room offers, in the order they read.
/// Ids are view names in docs/architecture/views.c4.
export const perspectives = [
	{ id: 'index', label: 'Landscape', blurb: 'Everything, one level deep.' },
	{ id: 'context', label: 'The Mac app', blurb: 'What Timbre touches, and what touches it.' },
	{ id: 'pipeline', label: 'Inside TimbreKit', blurb: 'One pipeline, one dictation at a time.' },
	{ id: 'run', label: 'Site and Backstage', blurb: 'How the product is run and released.' },
	{ id: 'learn', label: 'The Library (planned)', blurb: 'The store, the phone, and sync.' }
] as const;

export type PerspectiveId = (typeof perspectives)[number]['id'];
