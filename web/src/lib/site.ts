/// The one place the site knows its own address. Everything that needs an
/// absolute URL — canonical links, og:url, the sitemap — derives from this.
export const site = {
	origin: 'https://timbre.hugopretorius.dev',
	name: 'Timbre',
	description:
		'Free, on-device dictation for macOS. Hold a key, speak, release — cleaned-up text appears wherever you type. Zero network requests.'
} as const;
