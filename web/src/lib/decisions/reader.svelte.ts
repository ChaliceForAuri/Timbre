import { browser } from '$app/environment';

/// Reads decision records aloud with the browser's own speech synthesis —
/// the bedtime use. Text is spoken in sentence-sized chunks because some
/// engines stop silently on long utterances; a generation counter keeps a
/// cancelled utterance's callbacks from driving a queue they no longer own.
export interface Speakable {
	id: string;
	title: string;
	plain: string;
}

const PREFERRED = /Siri|Premium|Enhanced|Samantha|Daniel|Moira|Karen|Google UK English/i;
const CHUNK = 220;

function chunk(text: string): string[] {
	const sentences = text.split(/(?<=[.!?])\s+|\n+/).filter((s) => s.trim());
	const out: string[] = [];
	let current = '';
	for (const sentence of sentences) {
		if (current && current.length + sentence.length + 1 > CHUNK) {
			out.push(current);
			current = sentence;
		} else {
			current = current ? `${current} ${sentence}` : sentence;
		}
	}
	if (current) out.push(current);
	return out;
}

function bestVoice(): SpeechSynthesisVoice | null {
	const voices = speechSynthesis.getVoices().filter((v) => v.lang.toLowerCase().startsWith('en'));
	return voices.find((v) => PREFERRED.test(v.name)) ?? voices.find((v) => v.default) ?? voices[0] ?? null;
}

class Reader {
	queue = $state<Speakable[]>([]);
	index = $state(-1);
	status = $state<'idle' | 'playing' | 'paused'>('idle');
	current = $derived(this.index >= 0 ? this.queue[this.index] : undefined);

	private chunks: string[] = [];
	private position = 0;
	private generation = 0;

	get supported(): boolean {
		return browser && 'speechSynthesis' in window;
	}

	play(items: Speakable[], from = 0) {
		if (!this.supported || items.length === 0) return;
		speechSynthesis.cancel();
		this.queue = items;
		this.index = from;
		this.status = 'playing';
		this.speakCurrent();
	}

	pause() {
		if (this.status !== 'playing') return;
		speechSynthesis.pause();
		this.status = 'paused';
	}

	resume() {
		if (this.status !== 'paused') return;
		speechSynthesis.resume();
		this.status = 'playing';
	}

	next() {
		if (this.index + 1 < this.queue.length) this.jump(this.index + 1);
		else this.stop();
	}

	previous() {
		this.jump(Math.max(0, this.index - 1));
	}

	stop() {
		this.generation += 1;
		if (this.supported) speechSynthesis.cancel();
		this.queue = [];
		this.index = -1;
		this.status = 'idle';
	}

	private jump(to: number) {
		this.generation += 1;
		speechSynthesis.cancel();
		this.index = to;
		this.status = 'playing';
		this.speakCurrent();
	}

	private speakCurrent() {
		const item = this.current;
		if (!item) return this.stop();
		this.chunks = chunk(`${item.title}. ${item.plain}`);
		this.position = 0;
		this.speakChunk(this.generation);
	}

	private speakChunk(generation: number) {
		if (generation !== this.generation) return;
		if (this.position >= this.chunks.length) return this.next();

		const utterance = new SpeechSynthesisUtterance(this.chunks[this.position++]);
		utterance.voice = bestVoice();
		utterance.rate = 1;
		utterance.onend = () => this.speakChunk(generation);
		utterance.onerror = (event) => {
			if (event.error === 'interrupted' || event.error === 'canceled') return;
			this.speakChunk(generation);
		};
		speechSynthesis.speak(utterance);
	}
}

export const reader = new Reader();
