// Audio follower: turns audio into 0..1 levels the page maps onto signals.
// This is the host side of spec/signals.md — the plugin only ever sees the number.
//
// Two audio paths feed the analyser:
//  - LoopClip: the bundled test clip, decoded once and looped by an AudioBufferSourceNode.
//    That loop is sample-accurate; a <video loop> is not (it seeks to 0 and flushes the decoder,
//    so every wrap slips by a few samples to a frame). The clip is also the transport clock.
//  - a media element, for clips the user loads; those are not pre-decoded.

export type Band = 'rms' | 'bass' | 'mid' | 'high';

const BANDS: Record<Exclude<Band, 'rms'>, [number, number]> = {
  bass: [40, 160],
  mid: [160, 2000],
  high: [2000, 8000]
};

export class AudioFollower {
  private ctx: AudioContext | null = null;
  private analyser: AnalyserNode | null = null;
  private gain: GainNode | null = null;
  private freq = new Float32Array(0);
  private time = new Float32Array(0);
  private elements = new Map<HTMLMediaElement, MediaElementAudioSourceNode>();

  /** The context is created lazily, inside the user gesture that starts playback. */
  context(): AudioContext {
    if (this.ctx) return this.ctx;
    this.ctx = new AudioContext();
    this.analyser = this.ctx.createAnalyser();
    this.analyser.fftSize = 2048;
    this.analyser.smoothingTimeConstant = 0.5;
    this.gain = this.ctx.createGain();
    this.analyser.connect(this.gain);
    this.gain.connect(this.ctx.destination);
    this.freq = new Float32Array(this.analyser.frequencyBinCount);
    this.time = new Float32Array(this.analyser.fftSize);
    return this.ctx;
  }

  /** Route a node into the analyser (and on to the speakers through the sound gain). */
  tap(node: AudioNode) {
    this.context();
    node.connect(this.analyser!);
  }

  /** Attach a media element. A media element can only ever have one source node, so this is cached. */
  attach(el: HTMLMediaElement) {
    if (this.elements.has(el)) return;
    const src = this.context().createMediaElementSource(el);
    this.elements.set(el, src);
    this.tap(src);
  }

  /** Speakers on or off. The analyser keeps running either way so signals still follow. */
  setSound(on: boolean) {
    if (this.gain) this.gain.gain.value = on ? 1 : 0;
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

/**
 * A decoded audio clip looped sample-accurately by Web Audio. Also the transport clock:
 * `time()` is the position inside the loop, which the page uses as plugin time and to keep
 * the (muted) video elements in step.
 */
export class LoopClip {
  private buffer: AudioBuffer | null = null;
  private node: AudioBufferSourceNode | null = null;
  private loopStart = 0;
  private loopLen = 0;
  private startedAt = 0; // ctx time at which position 0 of the loop would have played
  private paused = 0; // loop position while not playing
  private url = '';

  constructor(private follower: AudioFollower) {}

  get playing() {
    return this.node !== null;
  }

  get duration() {
    return this.loopLen;
  }

  /**
   * Decode `url` and loop its final `seconds`. Looping the tail, not the head, keeps the loop
   * exact whether or not the browser trims AAC priming samples from the front of the decode.
   */
  async load(url: string, seconds: number) {
    if (this.url === url && this.buffer) return;
    const ctx = this.follower.context();
    const bytes = await (await fetch(url)).arrayBuffer();
    const buf = await ctx.decodeAudioData(bytes);
    this.buffer = buf;
    this.url = url;
    this.loopLen = Math.min(seconds, buf.duration);
    this.loopStart = buf.duration - this.loopLen;
    this.paused = 0;
  }

  play(offset = this.paused) {
    if (!this.buffer || this.node) return;
    const ctx = this.follower.context();
    const n = ctx.createBufferSource();
    n.buffer = this.buffer;
    n.loop = true;
    n.loopStart = this.loopStart;
    n.loopEnd = this.loopStart + this.loopLen;
    this.follower.tap(n);
    const pos = ((offset % this.loopLen) + this.loopLen) % this.loopLen;
    n.start(0, this.loopStart + pos);
    this.startedAt = ctx.currentTime - pos;
    this.node = n;
  }

  pause() {
    if (!this.node) return;
    this.paused = this.time();
    this.node.stop();
    this.node.disconnect();
    this.node = null;
  }

  /** Position inside the loop, in seconds. */
  time(): number {
    if (!this.node || this.loopLen === 0) return this.paused;
    const t = this.follower.context().currentTime - this.startedAt;
    return ((t % this.loopLen) + this.loopLen) % this.loopLen;
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
