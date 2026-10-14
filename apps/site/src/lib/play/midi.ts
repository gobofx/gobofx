// Web MIDI input → controller and note state the page maps onto signals.
// Browsers expose MIDI 1.0 bytes through Web MIDI today; values are upscaled to 0..1
// exactly as spec/signals.md asks a host to do for a MIDI 1.0 source.

export type NoteMode = 'gate' | 'velocity' | 'pitch' | 'pressure';

export type SignalBinding = {
  cc?: number;
  note?: number;
  notes?: [number, number];
  control?: 'bend' | 'pressure';
  mode?: NoteMode;
  channel?: number; // 1..16, absent = any
};

/** Computer keyboard as a stand-in controller: one octave from A (= note 36, C1) up to K (= 48). */
export const KEY_NOTES: Record<string, number> = {
  a: 36, w: 37, s: 38, e: 39, d: 40, f: 41, t: 42, g: 43, y: 44, h: 45, u: 46, j: 47, k: 48
};
/** Bend down / up while held; Shift is full channel pressure. */
export const KEY_BEND: Record<string, number> = { ArrowLeft: 0, ArrowRight: 1 };
export const KEY_PRESSURE = 'Shift';

const KBD = 'kbd'; // pseudo channel for the computer keyboard

type Held = { ch: number | typeof KBD; note: number; vel: number; order: number };

export class MidiInput {
  /** cc value by "channel:cc" (channel 0..15), 0..1 */
  private cc = new Map<string, number>();
  /** held notes by "channel:note" */
  private held = new Map<string, Held>();
  /** per-note pressure by "channel:note", 0..1 */
  private polyPressure = new Map<string, number>();
  /** channel pressure by channel, 0..1 */
  private pressure = new Map<number | typeof KBD, number>();
  /** pitch bend by channel, 0..1 (0.5 at rest) */
  private bend = new Map<number | typeof KBD, number>();
  private bendLatest: number | typeof KBD | null = null;
  /** recent note-ons, newest last, for the latched `pitch` mode */
  private recentOns: Held[] = [];
  private order = 0;
  available = false;
  inputs: string[] = [];
  lastEvent = '';

  /** Let the computer keyboard play while no text field has focus. Returns a detach function. */
  attachKeyboard(target: Window): () => void {
    const typing = (e: KeyboardEvent) => {
      const el = e.target as HTMLElement | null;
      return !!el && (el.tagName === 'INPUT' || el.tagName === 'SELECT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
    };
    const down = (e: KeyboardEvent) => {
      if (e.repeat || e.metaKey || e.ctrlKey || e.altKey || typing(e)) return;
      if (e.key === KEY_PRESSURE) {
        this.pressure.set(KBD, 1);
        this.lastEvent = 'shift → pressure 1';
        return;
      }
      if (e.key in KEY_BEND) {
        this.bend.set(KBD, KEY_BEND[e.key]);
        this.bendLatest = KBD;
        this.lastEvent = `${e.key === 'ArrowLeft' ? '←' : '→'} bend ${KEY_BEND[e.key]}`;
        e.preventDefault();
        return;
      }
      const note = KEY_NOTES[e.key.toLowerCase()];
      if (note === undefined) return;
      this.noteOn(KBD, note, 1);
      this.lastEvent = `key ${e.key.toUpperCase()} → note on ${note}`;
    };
    const up = (e: KeyboardEvent) => {
      if (e.key === KEY_PRESSURE) this.pressure.set(KBD, 0);
      if (e.key in KEY_BEND) {
        this.bend.set(KBD, 0.5);
        this.bendLatest = KBD;
      }
      const note = KEY_NOTES[e.key.toLowerCase()];
      if (note !== undefined) this.noteOff(KBD, note);
    };
    const blur = () => {
      for (const [k, h] of [...this.held]) if (h.ch === KBD) this.held.delete(k);
      this.pressure.set(KBD, 0);
      this.bend.set(KBD, 0.5);
    };
    target.addEventListener('keydown', down);
    target.addEventListener('keyup', up);
    target.addEventListener('blur', blur);
    return () => {
      target.removeEventListener('keydown', down);
      target.removeEventListener('keyup', up);
      target.removeEventListener('blur', blur);
    };
  }

  async connect(): Promise<boolean> {
    if (!('requestMIDIAccess' in navigator)) return false;
    try {
      const access = await navigator.requestMIDIAccess({ sysex: false });
      const wire = () => {
        this.inputs = [];
        access.inputs.forEach((input) => {
          this.inputs.push(input.name ?? input.id);
          input.onmidimessage = (e) => this.onMessage(e);
        });
      };
      wire();
      access.onstatechange = wire;
      this.available = true;
      return true;
    } catch {
      return false;
    }
  }

  private noteOn(ch: number | typeof KBD, note: number, vel: number) {
    const h: Held = { ch, note, vel, order: this.order++ };
    this.held.set(`${ch}:${note}`, h);
    this.recentOns.push(h);
    if (this.recentOns.length > 64) this.recentOns.shift();
  }

  private noteOff(ch: number | typeof KBD, note: number) {
    this.held.delete(`${ch}:${note}`);
    this.polyPressure.delete(`${ch}:${note}`);
  }

  private onMessage(e: MIDIMessageEvent) {
    const d = e.data;
    if (!d || d.length < 2) return;
    const status = d[0] & 0xf0;
    const ch = d[0] & 0x0f;
    if (status === 0xb0 && d.length >= 3) {
      this.cc.set(`${ch}:${d[1]}`, d[2] / 127);
      this.lastEvent = `cc ${d[1]} = ${d[2]} (ch ${ch + 1})`;
    } else if (status === 0x90 && d.length >= 3 && d[2] > 0) {
      this.noteOn(ch, d[1], d[2] / 127);
      this.lastEvent = `note on ${d[1]} vel ${d[2]} (ch ${ch + 1})`;
    } else if (status === 0x80 || (status === 0x90 && d.length >= 3 && d[2] === 0)) {
      this.noteOff(ch, d[1]);
      this.lastEvent = `note off ${d[1]} (ch ${ch + 1})`;
    } else if (status === 0xa0 && d.length >= 3) {
      this.polyPressure.set(`${ch}:${d[1]}`, d[2] / 127);
      this.lastEvent = `pressure note ${d[1]} = ${d[2]} (ch ${ch + 1})`;
    } else if (status === 0xd0) {
      this.pressure.set(ch, d[1] / 127);
      this.lastEvent = `pressure ${d[1]} (ch ${ch + 1})`;
    } else if (status === 0xe0 && d.length >= 3) {
      // 14-bit, 8192 at rest → 0.5; upscaled as spec/signals.md asks for a MIDI 1.0 source
      this.bend.set(ch, ((d[2] << 7) | d[1]) / 16383);
      this.bendLatest = ch;
      this.lastEvent = `bend ${(((d[2] << 7) | d[1]) - 8192)} (ch ${ch + 1})`;
    }
  }

  /** Current 0..1 value for a signal binding. */
  value(b: SignalBinding): number {
    const channels: (number | typeof KBD)[] = b.channel ? [b.channel - 1, KBD] : [...Array(16).keys(), KBD];
    const onCh = (ch: number | typeof KBD) => channels.includes(ch);

    if (b.cc !== undefined) {
      let v = 0;
      for (const ch of channels) v = Math.max(v, this.cc.get(`${ch}:${b.cc}`) ?? 0);
      return v;
    }
    if (b.control === 'bend') {
      if (this.bendLatest !== null && onCh(this.bendLatest)) return this.bend.get(this.bendLatest) ?? 0.5;
      return 0.5;
    }
    if (b.control === 'pressure') {
      let v = 0;
      for (const ch of channels) v = Math.max(v, this.pressure.get(ch) ?? 0);
      return v;
    }

    const [lo, hi] = b.notes ?? (b.note !== undefined ? [b.note, b.note] : [-1, -1]);
    if (lo < 0) return 0;
    const inRange = (h: Held) => h.note >= lo && h.note <= hi && onCh(h.ch);
    const mode = b.mode ?? 'gate';

    if (mode === 'pitch') {
      for (let i = this.recentOns.length - 1; i >= 0; i--) {
        const h = this.recentOns[i];
        if (inRange(h)) return hi > lo ? (h.note - lo) / (hi - lo) : 0;
      }
      return 0;
    }

    let newest: Held | null = null;
    let pressure = 0;
    for (const h of this.held.values()) {
      if (!inRange(h)) continue;
      if (!newest || h.order > newest.order) newest = h;
      pressure = Math.max(pressure, this.polyPressure.get(`${h.ch}:${h.note}`) ?? this.pressure.get(h.ch) ?? 0);
    }
    if (!newest) return 0;
    if (mode === 'velocity') return newest.vel;
    if (mode === 'pressure') return pressure;
    return 1; // gate
  }
}
