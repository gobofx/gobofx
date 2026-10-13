// Web MIDI input → controller and note state the page maps onto signals.
// Browsers expose MIDI 1.0 bytes through Web MIDI today; values are upscaled to 0..1
// exactly as spec/signals.md asks a host to do for a MIDI 1.0 source.

export type SignalBinding = {
  cc?: number;
  note?: number;
  mode?: 'gate' | 'velocity';
  channel?: number; // 1..16, absent = any
};

export class MidiInput {
  /** cc value by "channel:cc" (channel 0..15), 0..1 */
  private cc = new Map<string, number>();
  /** held notes by "channel:note" → velocity 0..1 */
  private notes = new Map<string, number>();
  available = false;
  inputs: string[] = [];
  lastEvent = '';

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

  private onMessage(e: MIDIMessageEvent) {
    const d = e.data;
    if (!d || d.length < 2) return;
    const status = d[0] & 0xf0;
    const ch = d[0] & 0x0f;
    if (status === 0xb0 && d.length >= 3) {
      this.cc.set(`${ch}:${d[1]}`, d[2] / 127);
      this.lastEvent = `cc ${d[1]} = ${d[2]} (ch ${ch + 1})`;
    } else if (status === 0x90 && d.length >= 3 && d[2] > 0) {
      this.notes.set(`${ch}:${d[1]}`, d[2] / 127);
      this.lastEvent = `note on ${d[1]} vel ${d[2]} (ch ${ch + 1})`;
    } else if (status === 0x80 || (status === 0x90 && d.length >= 3 && d[2] === 0)) {
      this.notes.delete(`${ch}:${d[1]}`);
      this.lastEvent = `note off ${d[1]} (ch ${ch + 1})`;
    }
  }

  /** Current 0..1 value for a signal binding. */
  value(b: SignalBinding): number {
    const channels = b.channel ? [b.channel - 1] : [...Array(16).keys()];
    if (b.cc !== undefined) {
      let v = 0;
      for (const ch of channels) v = Math.max(v, this.cc.get(`${ch}:${b.cc}`) ?? 0);
      return v;
    }
    if (b.note !== undefined) {
      for (const ch of channels) {
        const vel = this.notes.get(`${ch}:${b.note}`);
        if (vel !== undefined) return b.mode === 'velocity' ? vel : 1;
      }
    }
    return 0;
  }
}
