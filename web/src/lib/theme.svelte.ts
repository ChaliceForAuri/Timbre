import { browser } from '$app/environment';

/// Light or dark, as a choice that outlives the tab. app.html applies the
/// saved choice before first paint; this store is the runtime half. "system"
/// means follow the OS and is what a fresh visitor gets.
export type Theme = 'light' | 'dark' | 'system';

function read(): Theme {
	if (!browser) return 'system';
	try {
		const saved = localStorage.getItem('theme');
		return saved === 'light' || saved === 'dark' ? saved : 'system';
	} catch {
		return 'system';
	}
}

class ThemeStore {
	choice = $state<Theme>(read());
	dark = $derived(
		this.choice === 'system'
			? browser && window.matchMedia('(prefers-color-scheme: dark)').matches
			: this.choice === 'dark'
	);

	set(theme: Theme) {
		this.choice = theme;
		if (!browser) return;
		try {
			if (theme === 'system') localStorage.removeItem('theme');
			else localStorage.setItem('theme', theme);
		} catch {
			/* storage unavailable: the choice lasts for this page only */
		}
		document.documentElement.classList.toggle('dark', this.dark);
	}

	toggle() {
		this.set(this.dark ? 'light' : 'dark');
	}
}

export const theme = new ThemeStore();
