<script lang="ts">
  import { onMount } from 'svelte';
  import { examples, type ExamplePlugin } from '$lib/play/examples';
  import { AudioFollower, Envelope, type Band } from '$lib/play/follower';
  import { MidiInput } from '$lib/play/midi';

  type WebHost = {
    adapter_name(): string;
    load_plugin(manifestJson: string, shaders: Record<string, string>): Promise<string>;
    set_video(name: string, video: HTMLVideoElement): void;
    resize(width: number, height: number): void;
    render(time: number, progress: number, paramsJson: string, signalsJson: string): void;
  };

  type Param = {
    id: string;
    label?: string;
    type: 'float' | 'int' | 'bool' | 'choice' | 'color' | 'point';
    default?: unknown;
    min?: number;
    max?: number;
    unit?: string;
    options?: string[];
  };
  type Signal = {
    id: string;
    label?: string;
    cc?: number;
    note?: number;
    mode?: 'gate' | 'velocity';
    channel?: number;
    hint?: string;
    default?: number;
    attack_ms?: number;
    release_ms?: number;
  };
  type Manifest = { id: string; name: string; kind: 'effect' | 'transition'; params?: Param[]; signals?: Signal[] };
  type Diagnostic = { level: 'error' | 'warning'; file?: string; line?: number; message: string };
  type Report = { ok: boolean; diagnostics: Diagnostic[] };

  type SignalSource = 'manual' | 'rms' | 'bass' | 'mid' | 'high' | 'midi';

  // ── state ───────────────────────────────────────────────────────────
  let canvasEl = $state<HTMLCanvasElement>();
  let videoA = $state<HTMLVideoElement>();
  let videoB = $state<HTMLVideoElement>();
  let folderInput = $state<HTMLInputElement>();

  let host: WebHost | null = null;
  let supported = $state<boolean | null>(null);
  let bootError = $state('');
  let adapter = $state('');

  let pluginSlug = $state(examples[0]?.slug ?? '');
  let manifest = $state<Manifest | null>(null);
  let report = $state<Report | null>(null);
  let loadedName = $state('');
  let custom = $state<{ manifest: string; shaders: Record<string, string>; name: string } | null>(null);
  let dirHandle: FileSystemDirectoryHandle | null = null;

  let playing = $state(false);
  let sound = $state(true);
  let autoProgress = $state(true);
  let progress = $state(0.5);
  let fps = $state(0);

  let paramValues = $state<Record<string, unknown>>({});
  let signalManual = $state<Record<string, number>>({});
  let signalSource = $state<Record<string, SignalSource>>({});
  let signalLive = $state<Record<string, number>>({});

  const follower = new AudioFollower();
  const midi = new MidiInput();
  let midiState = $state<'off' | 'on' | 'none'>('off');
  let midiLast = $state('');
  const envelopes = new Map<string, Envelope>();

  const kind = $derived(manifest?.kind ?? 'effect');
  const params = $derived(manifest?.params ?? []);
  const signals = $derived(manifest?.signals ?? []);
  const errors = $derived(report?.diagnostics.filter((d) => d.level === 'error') ?? []);
  const warnings = $derived(report?.diagnostics.filter((d) => d.level === 'warning') ?? []);

  // ── boot ────────────────────────────────────────────────────────────
  onMount(() => {
    let raf = 0;
    let last = performance.now();
    let frames = 0;
    let fpsAt = last;

    (async () => {
      if (!('gpu' in navigator)) {
        supported = false;
        return;
      }
      try {
        const mod = await import('$lib/wasm/wispfx.js');
        await mod.default();
        host = (await mod.create_host(canvasEl!)) as unknown as WebHost;
        adapter = host.adapter_name();
        supported = true;
        await loadExample(pluginSlug);
      } catch (e) {
        supported = false;
        bootError = String(e);
        return;
      }

      const tick = (now: number) => {
        raf = requestAnimationFrame(tick);
        if (!host || !manifest || !report?.ok) return;
        const dt = now - last;
        last = now;
        try {
          const a = videoA!;
          const b = videoB!;
          const ready = a.readyState >= 2 && (kind !== 'transition' || b.readyState >= 2);
          if (!ready) return; // first frames not decoded yet; nothing to render
          host.set_video(kind === 'effect' ? 'source' : 'from', a);
          if (kind === 'transition') host.set_video('to', b);
          const dur = a.duration || 8;
          const t = a.currentTime || 0;
          const p = kind === 'transition' ? (autoProgress ? t / dur : progress) : t / dur;
          if (kind === 'transition' && autoProgress) progress = p;

          const sig: Record<string, number> = {};
          for (const s of signals) {
            const src = signalSource[s.id] ?? 'manual';
            let raw: number;
            if (src === 'manual') raw = signalManual[s.id] ?? s.default ?? 0;
            else if (src === 'midi') raw = midi.value(s);
            else raw = follower.level(src as Band);
            let env = envelopes.get(s.id);
            if (!env) {
              env = new Envelope(s.attack_ms ?? 0, s.release_ms ?? 0);
              envelopes.set(s.id, env);
            }
            sig[s.id] = src === 'manual' ? raw : env.step(raw, dt);
          }
          signalLive = sig;
          if (midi.available) midiLast = midi.lastEvent;

          host.render(t, p, JSON.stringify(paramValues), JSON.stringify(sig));
        } catch (e) {
          console.error(e);
        }
        frames++;
        if (now - fpsAt > 500) {
          fps = Math.round((frames * 1000) / (now - fpsAt));
          frames = 0;
          fpsAt = now;
        }
      };
      raf = requestAnimationFrame(tick);
    })();

    return () => cancelAnimationFrame(raf);
  });

  // ── plugin loading ──────────────────────────────────────────────────
  async function install(manifestText: string, shaders: Record<string, string>, name: string) {
    if (!host) return;
    let parsed: Manifest | null = null;
    try {
      parsed = JSON.parse(manifestText);
    } catch (e) {
      report = { ok: false, diagnostics: [{ level: 'error', file: 'manifest.json', message: `invalid JSON: ${e}` }] };
      manifest = null;
      return;
    }
    const json = await host.load_plugin(manifestText, shaders);
    report = JSON.parse(json);
    loadedName = name;
    if (report?.ok) {
      manifest = parsed;
      const pv: Record<string, unknown> = {};
      for (const p of parsed?.params ?? []) pv[p.id] = p.default ?? defaultFor(p);
      paramValues = pv;
      const sm: Record<string, number> = {};
      const ss: Record<string, SignalSource> = {};
      for (const s of parsed?.signals ?? []) {
        sm[s.id] = s.default ?? 0;
        ss[s.id] = signalSource[s.id] ?? 'manual';
      }
      signalManual = sm;
      signalSource = ss;
      envelopes.clear();
    } else {
      manifest = null;
    }
  }

  function defaultFor(p: Param): unknown {
    switch (p.type) {
      case 'float':
      case 'int':
      case 'choice':
        return 0;
      case 'bool':
        return false;
      case 'color':
        return [0, 0, 0, 1];
      case 'point':
        return [0.5, 0.5];
    }
  }

  async function loadExample(slug: string) {
    const ex: ExamplePlugin | undefined = examples.find((e) => e.slug === slug);
    if (!ex) return;
    custom = null;
    await install(ex.manifest, ex.shaders, ex.name);
  }

  async function readDir(handle: FileSystemDirectoryHandle) {
    let manifestText = '';
    const shaders: Record<string, string> = {};
    // @ts-expect-error: async iteration of directory handles is not in lib.dom yet
    for await (const [name, entry] of handle.entries()) {
      if (entry.kind !== 'file') continue;
      const file = await (entry as FileSystemFileHandle).getFile();
      if (name === 'manifest.json') manifestText = await file.text();
      else if (name.endsWith('.wgsl')) shaders[name] = await file.text();
    }
    custom = { manifest: manifestText, shaders, name: handle.name };
    await install(manifestText, shaders, handle.name);
  }

  async function openFolder() {
    if ('showDirectoryPicker' in window) {
      try {
        // @ts-expect-error: File System Access API
        dirHandle = await window.showDirectoryPicker({ mode: 'read' });
        if (dirHandle) await readDir(dirHandle);
      } catch {
        /* cancelled */
      }
    } else {
      folderInput?.click();
    }
  }

  async function onFolderFiles(e: Event) {
    const files = (e.target as HTMLInputElement).files;
    if (!files) return;
    let manifestText = '';
    const shaders: Record<string, string> = {};
    let name = 'folder';
    for (const f of files) {
      const parts = f.webkitRelativePath.split('/');
      if (parts.length > 1) name = parts[0];
      if (parts.length !== 2) continue; // top level of the chosen folder only
      if (f.name === 'manifest.json') manifestText = await f.text();
      else if (f.name.endsWith('.wgsl')) shaders[f.name] = await f.text();
    }
    custom = { manifest: manifestText, shaders, name };
    await install(manifestText, shaders, name);
  }

  async function reload() {
    if (dirHandle) await readDir(dirHandle);
    else if (custom) await install(custom.manifest, custom.shaders, custom.name);
    else await loadExample(pluginSlug);
  }

  // ── transport ───────────────────────────────────────────────────────
  async function togglePlay() {
    const a = videoA!;
    const b = videoB!;
    if (playing) {
      a.pause();
      b.pause();
      playing = false;
      return;
    }
    follower.attach(a);
    await follower.resume();
    a.muted = !sound;
    b.muted = true;
    await Promise.all([a.play(), b.play()]);
    playing = true;
  }

  function toggleSound() {
    sound = !sound;
    if (videoA) videoA.muted = !sound;
  }

  async function connectMidi() {
    const ok = await midi.connect();
    midiState = ok ? 'on' : 'none';
  }

  function useClip(slot: 'a' | 'b', e: Event) {
    const file = (e.target as HTMLInputElement).files?.[0];
    if (!file) return;
    const el = slot === 'a' ? videoA! : videoB!;
    el.src = URL.createObjectURL(file);
    el.load();
    if (playing) el.play();
  }

  function setColor(id: string, i: number, v: number) {
    const c = [...((paramValues[id] as number[]) ?? [0, 0, 0, 1])];
    c[i] = v;
    paramValues = { ...paramValues, [id]: c };
  }
  function setPoint(id: string, i: number, v: number) {
    const c = [...((paramValues[id] as number[]) ?? [0.5, 0.5])];
    c[i] = v;
    paramValues = { ...paramValues, [id]: c };
  }
  const num = (v: unknown, d = 0) => (typeof v === 'number' ? v : d);
</script>

<svelte:head>
  <title>WISPFX.ORG — play</title>
  <meta name="description" content="Run a WispFX plugin in the browser on WebGPU: pick a reference plugin or open your own folder, play test clips, drive signals from audio or MIDI." />
</svelte:head>

<section class="head">
  <div class="badge">WEBGPU · SAME CRATE AS THE CLI, COMPILED TO WASM</div>
  <h1 class="title">PLAY</h1>
  <div class="teaser">RUN A PLUGIN IN THE BROWSER</div>
</section>

{#if supported === false}
  <div class="card notice">
    <h3>WebGPU is not available here.</h3>
    <p>
      The play page needs a browser with WebGPU (current Chrome, Edge, or Safari). {#if bootError}Details: <code>{bootError}</code>{/if}
    </p>
  </div>
{/if}

<section class="play" class:hidden={supported === false}>
  <div class="toolbar">
    <label class="field">
      <span class="label">PLUGIN</span>
      <select bind:value={pluginSlug} onchange={() => loadExample(pluginSlug)} disabled={!!custom}>
        {#each examples as ex (ex.slug)}
          <option value={ex.slug}>{ex.name} · {ex.kind}</option>
        {/each}
      </select>
    </label>
    <button class="btn ghost" onclick={openFolder}>→ OPEN FOLDER</button>
    {#if custom}
      <button class="btn ghost" onclick={() => { custom = null; dirHandle = null; loadExample(pluginSlug); }}>→ BACK TO EXAMPLES</button>
    {/if}
    <button class="btn ghost" onclick={reload}>→ RELOAD</button>
    <input bind:this={folderInput} type="file" webkitdirectory multiple hidden onchange={onFolderFiles} />
    <span class="status" class:ok={report?.ok} class:fail={report && !report.ok}>
      {#if report}{report.ok ? 'OK' : 'FAIL'} · {loadedName}{/if}
    </span>
  </div>

  {#if errors.length || warnings.length}
    <ul class="diag">
      {#each errors as d, i (i)}
        <li class="err">error: {d.file ? `${d.file}${d.line ? ':' + d.line : ''}: ` : ''}{d.message}</li>
      {/each}
      {#each warnings as d, i (i)}
        <li class="warn">warning: {d.file ? `${d.file}: ` : ''}{d.message}</li>
      {/each}
    </ul>
  {/if}

  <div class="stage">
    <canvas bind:this={canvasEl} width="1280" height="720"></canvas>
    <div class="stageBar">
      <button class="btn primary" onclick={togglePlay}>{playing ? '❚❚ PAUSE' : '▶ PLAY'}</button>
      <button class="btn ghost" onclick={toggleSound}>{sound ? '🔊 SOUND ON' : '🔇 SOUND OFF'}</button>
      {#if kind === 'transition'}
        <label class="field inline">
          <span class="label">PROGRESS</span>
          <input type="range" min="0" max="1" step="0.001" bind:value={progress} oninput={() => (autoProgress = false)} />
          <span class="mono">{progress.toFixed(2)}</span>
          <button class="btn ghost small" onclick={() => (autoProgress = true)} disabled={autoProgress}>auto</button>
        </label>
      {/if}
      <span class="mono dim">{adapter}{fps ? ` · ${fps} fps` : ''}</span>
    </div>
  </div>

  <div class="panels">
    <div class="panel">
      <div class="sectionHeader">CLIPS</div>
      <div class="clips">
        <div class="clip">
          <video bind:this={videoA} src="/media/a.mp4" loop playsinline preload="auto" crossorigin="anonymous" muted></video>
          <div class="clipLabel">
            <span class="mono">{kind === 'transition' ? 'from' : 'source'}</span>
            <label class="btn ghost small">own clip <input type="file" accept=".mp4,.mov,.webm,.m4v" hidden onchange={(e) => useClip('a', e)} /></label>
          </div>
        </div>
        <div class="clip" class:unused={kind !== 'transition'}>
          <video bind:this={videoB} src="/media/b.mp4" loop playsinline preload="auto" crossorigin="anonymous" muted></video>
          <div class="clipLabel">
            <span class="mono">to</span>
            <label class="btn ghost small">own clip <input type="file" accept=".mp4,.mov,.webm,.m4v" hidden onchange={(e) => useClip('b', e)} /></label>
          </div>
        </div>
      </div>
      <p class="dim small">Test clips are synthetic. Clip A carries a kick-drum pattern for the audio follower.</p>
    </div>

    <div class="panel">
      <div class="sectionHeader">PARAMS</div>
      {#if params.length === 0}
        <p class="dim small">This plugin declares no params.</p>
      {/if}
      {#each params as p (p.id)}
        <div class="control">
          <div class="controlHead">
            <span>{p.label ?? p.id}</span>
            <span class="mono dim">{p.id}{p.unit ? ` · ${p.unit}` : ''}</span>
          </div>
          {#if p.type === 'float'}
            <div class="row">
              <input type="range" min={p.min ?? 0} max={p.max ?? 1} step={((p.max ?? 1) - (p.min ?? 0)) / 400}
                value={num(paramValues[p.id])} oninput={(e) => (paramValues = { ...paramValues, [p.id]: Number((e.target as HTMLInputElement).value) })} />
              <span class="mono">{num(paramValues[p.id]).toFixed(3)}</span>
            </div>
          {:else if p.type === 'int'}
            <div class="row">
              <input type="range" min={p.min ?? 0} max={p.max ?? 10} step="1"
                value={num(paramValues[p.id])} oninput={(e) => (paramValues = { ...paramValues, [p.id]: Number((e.target as HTMLInputElement).value) })} />
              <span class="mono">{num(paramValues[p.id])}</span>
            </div>
          {:else if p.type === 'bool'}
            <label class="row"><input type="checkbox" checked={!!paramValues[p.id]} onchange={(e) => (paramValues = { ...paramValues, [p.id]: (e.target as HTMLInputElement).checked })} /> <span class="mono">{paramValues[p.id] ? 'true' : 'false'}</span></label>
          {:else if p.type === 'choice'}
            <select value={num(paramValues[p.id])} onchange={(e) => (paramValues = { ...paramValues, [p.id]: Number((e.target as HTMLSelectElement).value) })}>
              {#each p.options ?? [] as o, i (o)}<option value={i}>{o}</option>{/each}
            </select>
          {:else if p.type === 'color'}
            <div class="row">
              {#each ['r', 'g', 'b', 'a'] as ch, i (ch)}
                <label class="mini"><span class="mono dim">{ch}</span><input type="range" min="0" max="1" step="0.001" value={((paramValues[p.id] as number[]) ?? [0, 0, 0, 1])[i]} oninput={(e) => setColor(p.id, i, Number((e.target as HTMLInputElement).value))} /></label>
              {/each}
            </div>
          {:else if p.type === 'point'}
            <div class="row">
              {#each ['x', 'y'] as ch, i (ch)}
                <label class="mini"><span class="mono dim">{ch}</span><input type="range" min="0" max="1" step="0.001" value={((paramValues[p.id] as number[]) ?? [0.5, 0.5])[i]} oninput={(e) => setPoint(p.id, i, Number((e.target as HTMLInputElement).value))} /></label>
              {/each}
            </div>
          {/if}
        </div>
      {/each}
    </div>

    <div class="panel">
      <div class="sectionHeader">SIGNALS</div>
      {#if signals.length === 0}
        <p class="dim small">This plugin declares no signals.</p>
      {:else}
        <p class="dim small">
          Each signal is a MIDI 2.0 controller or note on the plugin's input. Here the host side is a slider, an audio follower on clip A, or your MIDI device.
        </p>
      {/if}
      {#each signals as s (s.id)}
        <div class="control">
          <div class="controlHead">
            <span>{s.label ?? s.id}</span>
            <span class="mono dim">{s.cc !== undefined ? `cc ${s.cc}` : `note ${s.note} ${s.mode ?? 'gate'}`}{s.hint ? ` · ${s.hint}` : ''}</span>
          </div>
          <div class="row">
            <select value={signalSource[s.id] ?? 'manual'} onchange={(e) => (signalSource = { ...signalSource, [s.id]: (e.target as HTMLSelectElement).value as SignalSource })}>
              <option value="manual">slider</option>
              <option value="bass">audio · bass 40–160 Hz</option>
              <option value="mid">audio · mid 160–2k Hz</option>
              <option value="high">audio · high 2–8 kHz</option>
              <option value="rms">audio · level</option>
              <option value="midi">MIDI</option>
            </select>
            {#if (signalSource[s.id] ?? 'manual') === 'manual'}
              <input type="range" min="0" max="1" step="0.001" value={signalManual[s.id] ?? 0} oninput={(e) => (signalManual = { ...signalManual, [s.id]: Number((e.target as HTMLInputElement).value) })} />
            {:else}
              <div class="meter"><div class="meterFill" style="width: {Math.round((signalLive[s.id] ?? 0) * 100)}%"></div></div>
            {/if}
            <span class="mono">{(signalLive[s.id] ?? signalManual[s.id] ?? 0).toFixed(2)}</span>
          </div>
        </div>
      {/each}
      {#if signals.some((s) => (signalSource[s.id] ?? 'manual') === 'midi')}
        <div class="row">
          <button class="btn ghost small" onclick={connectMidi} disabled={midiState === 'on'}>→ CONNECT MIDI</button>
          <span class="mono dim">{midiState === 'on' ? (midi.inputs.length ? midi.inputs.join(', ') : 'no inputs') : midiState === 'none' ? 'Web MIDI unavailable' : ''}{midiLast ? ` · ${midiLast}` : ''}</span>
        </div>
      {/if}
    </div>
  </div>
</section>

<style>
  .head {
    padding-top: clamp(1.5rem, 5vh, 3rem);
  }
  .title {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: clamp(2.5rem, 8vw, 5rem);
    line-height: 0.95;
    letter-spacing: -0.02em;
    margin: 0;
    background: linear-gradient(135deg, #ffffff 0%, #c2c2c2 35%, #f2a65a 75%, #ff6b8b 100%);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
  }
  .teaser {
    font-family: var(--font-display);
    font-weight: 300;
    font-size: clamp(0.8rem, 1.4vw, 1rem);
    letter-spacing: 0.32em;
    color: var(--text-muted);
    margin: 1rem 0 2rem;
  }
  .notice {
    max-width: 44rem;
  }
  .hidden {
    display: none;
  }

  .toolbar {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.75rem;
    margin-bottom: 1rem;
  }
  .field {
    display: inline-flex;
    align-items: center;
    gap: 0.6rem;
  }
  .field.inline {
    flex: 1;
    min-width: 16rem;
  }
  .label {
    font-family: var(--font-mono);
    font-size: 0.72rem;
    letter-spacing: 0.18em;
    color: var(--accent-teal);
  }
  select,
  input[type='range'] {
    accent-color: var(--accent);
  }
  select {
    background: var(--bg-elev);
    color: var(--text);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 0.5rem 0.7rem;
    font-family: var(--font-mono);
    font-size: 0.85rem;
  }
  input[type='range'] {
    flex: 1;
    min-width: 6rem;
  }
  .status {
    font-family: var(--font-mono);
    font-size: 0.85rem;
    color: var(--text-dim);
    margin-left: auto;
  }
  .status.ok {
    color: #5ee3a0;
  }
  .status.fail {
    color: var(--accent-coral);
  }
  .diag {
    list-style: none;
    margin: 0 0 1rem;
    padding: 0.75rem 1rem;
    background: var(--bg-elev);
    border: 1px solid var(--border-soft);
    border-radius: 6px;
    font-family: var(--font-mono);
    font-size: 0.82rem;
    display: grid;
    gap: 0.3rem;
  }
  .diag .err {
    color: var(--accent-coral);
  }
  .diag .warn {
    color: var(--accent);
  }

  .stage {
    background: #000;
    border: 1px solid var(--border-soft);
    border-radius: 10px;
    overflow: hidden;
  }
  canvas {
    display: block;
    width: 100%;
    aspect-ratio: 16 / 9;
    background: #000;
  }
  .stageBar {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.75rem;
    padding: 0.75rem 1rem;
    background: var(--bg-elev);
    border-top: 1px solid var(--border-soft);
  }
  .btn.small {
    padding: 0.4rem 0.7rem;
    font-size: 0.72rem;
  }
  .mono {
    font-family: var(--font-mono);
    font-size: 0.82rem;
  }
  .small {
    font-size: 0.85rem;
  }

  .panels {
    display: grid;
    gap: 1rem;
    grid-template-columns: repeat(auto-fit, minmax(18rem, 1fr));
    margin-top: 1rem;
  }
  .panel {
    background: var(--bg-elev);
    border: 1px solid var(--border-soft);
    border-radius: 10px;
    padding: 1.25rem;
  }
  .clips {
    display: grid;
    gap: 0.75rem;
    grid-template-columns: 1fr 1fr;
  }
  .clip video {
    width: 100%;
    aspect-ratio: 16 / 9;
    background: #000;
    border-radius: 6px;
    display: block;
  }
  .clip.unused {
    opacity: 0.35;
  }
  .clipLabel {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: 0.4rem;
  }
  .control {
    padding: 0.6rem 0;
    border-bottom: 1px dashed var(--border-soft);
  }
  .control:last-of-type {
    border-bottom: 0;
  }
  .controlHead {
    display: flex;
    justify-content: space-between;
    gap: 0.5rem;
    font-size: 0.9rem;
    margin-bottom: 0.3rem;
    flex-wrap: wrap;
  }
  .row {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    flex-wrap: wrap;
  }
  .mini {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    flex: 1;
    min-width: 5rem;
  }
  .meter {
    flex: 1;
    height: 10px;
    background: var(--bg);
    border: 1px solid var(--border-soft);
    border-radius: 999px;
    overflow: hidden;
    min-width: 6rem;
  }
  .meterFill {
    height: 100%;
    background: linear-gradient(90deg, var(--accent-deep), var(--accent-coral));
    transition: width 40ms linear;
  }
</style>
