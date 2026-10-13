// Audio follower: turns a <video>'s audio into 0..1 levels the page maps onto signals.
// This is the host side of spec/signals.md — the plugin only ever sees the number.

export type Band = 'rms' | 'bass' | 'mid' | 'high';

const BANDS: Record<Exclude<Band, 'rms'>, [number, number]> = {
  bass: [40, 160],
  mid: [160, 2000],
  high: [2000, 8000]
};

export class AudioFollower {
  private ctx: AudioContext | null = null;
  private analyser: AnalyserNode | null = null;
  private source: MediaElementAudioSourceNode | null = null;
  private freq = new Float32Array(0);
  private time = new Float32Array(0);
  private attached: HTMLMediaElement | null = null;

  /** Attach to a media element (once per element; a media element can only have one source node). */
  attach(el: HTMLMediaElement) {
    if (this.attached === el) return;
    if (this.attached) return; // one follower per element for the life of the page
    this.ctx = new AudioContext();
    this.analyser = this.ctx.createAnalyser();
    this.analyser.fftSize = 2048;
    this.analyser.smoothingTimeConstant = 0.5;
    this.source = this.ctx.createMediaElementSource(el);
    this.source.connect(this.analyser);
    this.analyser.connect(this.ctx.destination);
    this.freq = new Float32Array(this.analyser.frequencyBinCount);
    this.time = new Float32Array(this.analyser.fftSize);
    this.attached = el;
  }

  async resume() {
    if (this.ctx && this.ctx.state !== 'running') await this.ctx.resume();
  }

  /** Read a 0..1 level for a band. Call once per frame per band. */
  level(band: Band): number {
    if (!this.analyser || !this.ctx) return 0;
    if (band === 'rms') {
      this.analyser.getFloatTimeDomainData(this.time);
      let sum = 0;
      for (let i = 0; i < this.time.length; i++) sum += this.time[i] * this.time[i];
      const rms = Math.sqrt(sum / this.time.length);
      return Math.min(1, rms * 4); // -12 dBFS → 1
    }
    this.analyser.getFloatFrequencyData(this.freq);
    const [lo, hi] = BANDS[band];
    const hzPerBin = this.ctx.sampleRate / this.analyser.fftSize;
    const a = Math.max(0, Math.floor(lo / hzPerBin));
    const b = Math.min(this.freq.length - 1, Math.ceil(hi / hzPerBin));
    let acc = 0;
    let n = 0;
    for (let i = a; i <= b; i++) {
      acc += this.freq[i];
      n++;
    }
    if (n === 0) return 0;
    const db = acc / n; // typically -100..0
    return Math.min(1, Math.max(0, (db + 60) / 60)); // -60 dB → 0, 0 dB → 1
  }
}

/** One-pole attack/release envelope as described in spec/signals.md. */
export class Envelope {
  private y = 0;
  constructor(
    public attackMs = 0,
    public releaseMs = 0
  ) {}
  step(x: number, dtMs: number): number {
    const tau = x > this.y ? this.attackMs : this.releaseMs;
    if (tau <= 0) {
      this.y = x;
    } else {
      const k = 1 - Math.exp(-dtMs / tau);
      this.y += (x - this.y) * k;
    }
    return this.y;
  }
}
