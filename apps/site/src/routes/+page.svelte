<script lang="ts">
  const repo = 'https://github.com/taluvi-dev/wispfx';
  const frames = Array.from({ length: 14 }, (_, i) => i);

  // Verbatim from spec/examples/cross-dissolve — keep in sync.
  const manifest = `{
  "wisp": "0.1",
  "id": "org.wispfx.cross-dissolve",
  "name": "Cross Dissolve",
  "kind": "transition",
  "category": "dissolve",
  "version": "0.1.0",
  "license": "MIT OR Apache-2.0",
  "params": [
    { "id": "ease", "label": "Ease", "type": "float",
      "default": 0.0, "min": 0.0, "max": 1.0, "animatable": true }
  ],
  "passes": [
    { "shader": "shader.wgsl", "entry": "fs_main",
      "inputs": ["from", "to"], "output": "out" }
  ]
}`;

  const shader = `struct Params {
    ease: f32,
}
@group(1) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let a = textureSampleLevel(wisp_input0, wisp_sampler, uv, 0.0);
    let b = textureSampleLevel(wisp_input1, wisp_sampler, uv, 0.0);
    let p = clamp(wisp_globals.progress, 0.0, 1.0);
    let t = mix(p, smoothstep(0.0, 1.0, p), params.ease);
    return mix(a, b, t); // premultiplied: a plain mix is correct
}`;

  const cards = [
    {
      tag: '01 / FORMAT',
      title: 'Manifest + WGSL',
      text: 'A plugin is a folder: manifest.json plus one or more WGSL files. Typed params, ordered passes, and nothing a host has to guess.'
    },
    {
      tag: '02 / KINDS',
      title: 'Effect and transition',
      text: 'An effect takes one input, source. A transition takes from and to plus a progress the host drives from 0 to 1 across the cut.'
    },
    {
      tag: '03 / ABI',
      title: 'One host prelude',
      text: 'The host prepends a prelude that declares every binding and the vertex stage. A plugin writes fs_main and never its own samplers or textures.'
    },
    {
      tag: '04 / PORTABLE',
      title: 'wgpu and WebGPU',
      text: 'Linear premultiplied rgba16float in and out, WGSL both naga and the browser accept, no extensions. A native host and a browser host draw the same frame.'
    }
  ];
</script>

<svelte:head>
  <title>WISPFX.ORG — open standard for video effects and transitions</title>
  <meta
    name="description"
    content="WispFX is an open standard for portable video effects and transitions: a JSON manifest plus WGSL shaders, running identically in native wgpu hosts and in the browser via WebGPU." />
  <meta property="og:title" content="WISPFX.ORG" />
  <meta property="og:description" content="Open standard for portable video effects and transitions: JSON manifest plus WGSL, native wgpu and browser WebGPU." />
  <meta property="og:type" content="website" />
  <meta property="og:url" content="https://wispfx.org/" />
</svelte:head>

<section class="hero">
  <div class="badge">DRAFT 0.1 · OPEN STANDARD · UNSTABLE</div>

  <h1 class="title">WISPFX<span class="titleTld">.ORG</span></h1>
  <div class="teaser">PORTABLE VIDEO EFFECTS &amp; TRANSITIONS</div>

  <p class="lede">
    The visual sibling of <a href="https://plinken.org" target="_blank" rel="noreferrer noopener">plinken.org</a>.
    A WispFX plugin is a JSON manifest plus WGSL shaders, and it renders identically in native
    <code>wgpu</code> hosts and in the browser through WebGPU. Write an effect or a transition once,
    run it in any host that speaks the standard.
  </p>

  <div class="actions">
    <a class="btn primary" href="/spec">→ READ THE SPEC</a>
    <a class="btn ghost" href={repo} target="_blank" rel="noreferrer noopener">→ GITHUB</a>
    <a class="btn ghost" href="{repo}/tree/main/spec/examples" target="_blank" rel="noreferrer noopener">→ EXAMPLES</a>
  </div>

  <div class="frames" aria-hidden="true">
    {#each frames as i (i)}
      <span class="frame" style="--i: {i}"></span>
    {/each}
  </div>
</section>

<section class="grid cards">
  {#each cards as c (c.tag)}
    <article class="card">
      <div class="cardTag">{c.tag}</div>
      <h2>{c.title}</h2>
      <p>{c.text}</p>
    </article>
  {/each}
</section>

<section class="section">
  <div class="sectionHeader">EXAMPLE · CROSS DISSOLVE</div>
  <p class="lede small">
    <code>manifest.json</code> declares what the plugin is, its params and its passes. <code>shader.wgsl</code>
    is the fragment code. The host prepends
    <a href="{repo}/blob/main/spec/prelude.wgsl" target="_blank" rel="noreferrer noopener">the prelude</a> and compiles.
  </p>
  <div class="example">
    <div>
      <div class="filename">manifest.json</div>
      <pre><code>{manifest}</code></pre>
    </div>
    <div>
      <div class="filename">shader.wgsl</div>
      <pre><code>{shader}</code></pre>
    </div>
  </div>
</section>

<section class="section">
  <div class="sectionHeader">HOST BINDINGS</div>
  <ul class="stack">
    <li><span>0 / 0</span><span>wisp_sampler · sampler, linear filter, clamp to edge</span></li>
    <li><span>0 / 1</span><span>wisp_globals · uniform WispGlobals: resolution, texel, time, progress</span></li>
    <li><span>0 / 2</span><span>wisp_input0 · texture_2d&lt;f32&gt;, first pass input</span></li>
    <li><span>0 / 3</span><span>wisp_input1 · texture_2d&lt;f32&gt;, second pass input, or 1×1 transparent</span></li>
    <li><span>1 / 0</span><span>params · uniform Params, declared by the plugin to match the manifest</span></li>
    <li><span>ENTRY</span><span>@fragment fn fs_main(@location(0) uv: vec2f) -&gt; @location(0) vec4f</span></li>
    <li><span>COLOUR</span><span>linear, premultiplied RGBA, rgba16float, Rec. 709 primaries, HDR allowed</span></li>
  </ul>
</section>

<section class="section">
  <div class="sectionHeader">STACK</div>
  <ul class="stack">
    <li><span>SHADERS</span><span>WGSL · naga and browser WebGPU, no extensions</span></li>
    <li><span>NATIVE</span><span>wgpu</span></li>
    <li><span>BROWSER</span><span>WebGPU</span></li>
    <li><span>REFERENCE</span><span>Rust crate: parse, validate, assemble · planned</span></li>
    <li><span>FIRST HOST</span><span>Plinken · browser compositor and native runner</span></li>
    <li><span>LICENSE</span><span>MIT OR Apache-2.0 · DCO sign-off</span></li>
  </ul>
</section>

<style>
  .hero {
    padding-top: clamp(2rem, 8vh, 5rem);
  }
  .title {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: clamp(2.75rem, 11vw, 7rem);
    line-height: 0.95;
    letter-spacing: -0.02em;
    margin: 0;
    background: linear-gradient(135deg, #ffffff 0%, #c2c2c2 35%, #f2a65a 75%, #ff6b8b 100%);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
  }
  .titleTld {
    -webkit-text-fill-color: var(--text-dim);
    font-weight: 300;
  }
  .teaser {
    font-family: var(--font-display);
    font-weight: 300;
    font-size: clamp(0.85rem, 1.6vw, 1.1rem);
    letter-spacing: 0.32em;
    color: var(--text-muted);
    margin: 1.25rem 0 2.5rem;
  }
  .actions {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
    margin-bottom: 3.5rem;
  }

  /* ─── dissolving frames: the visual counterpart of plinken.org's audio bars ─── */
  .frames {
    display: flex;
    gap: 4px;
    height: 36px;
    opacity: 0.85;
  }
  .frame {
    flex: 1;
    border-radius: 2px;
    background: linear-gradient(135deg, var(--accent-deep), var(--accent-coral));
    animation: dissolve 2.4s ease-in-out infinite;
    animation-delay: calc(var(--i) * 110ms);
  }
  @keyframes dissolve {
    0%,
    100% {
      opacity: 0.18;
      transform: scaleY(0.6);
    }
    50% {
      opacity: 1;
      transform: scaleY(1);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .frame {
      animation: none;
      opacity: 0.6;
    }
  }

  .cards {
    margin: 5rem 0;
  }
  .lede.small {
    font-size: 1rem;
    margin-bottom: 1.5rem;
  }
  .example {
    display: grid;
    gap: 1rem;
    grid-template-columns: repeat(auto-fit, minmax(20rem, 1fr));
  }
  .filename {
    font-family: var(--font-mono);
    font-size: 0.78rem;
    letter-spacing: 0.08em;
    color: var(--text-dim);
    margin-bottom: 0.4rem;
  }
</style>
