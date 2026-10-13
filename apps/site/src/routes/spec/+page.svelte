<script lang="ts">
  const blob = 'https://github.com/taluvi-dev/wispfx/blob/main/spec/';
  const tree = 'https://github.com/taluvi-dev/wispfx/tree/main/spec/';

  const files = [
    {
      tag: '01 / MANIFEST',
      href: blob + 'manifest.md',
      file: 'manifest.md',
      summary:
        'Top-level fields (wisp, id, name, kind, category, version, license), the params table with its WGSL mapping, and the passes table: shader, entry, constants, inputs and output. Reserved input names source, from and to.'
    },
    {
      tag: '02 / SCHEMA',
      href: blob + 'manifest.schema.json',
      file: 'manifest.schema.json',
      summary: 'Draft 2020-12 JSON Schema for manifest.json, published at wispfx.org/schema/0.1/manifest.json. Validate before shipping.'
    },
    {
      tag: '03 / ABI',
      href: blob + 'shader-abi.md',
      file: 'shader-abi.md',
      summary:
        'Module assembly (prelude plus plugin file), the five host bindings, the fragment entry point, the colour space (linear, premultiplied RGBA, rgba16float, Rec. 709) and the portability rules.'
    },
    {
      tag: '04 / SIGNALS',
      href: blob + 'signals.md',
      file: 'signals.md',
      summary:
        'MIDI 2.0 controllers and notes a plugin reads each frame as 0..1 floats at group 1, binding 1. The host maps audio followers, OSC and hardware onto them; the plugin never sees events.'
    },
    {
      tag: '05 / PRELUDE',
      href: blob + 'prelude.wgsl',
      file: 'prelude.wgsl',
      summary:
        'The WGSL the host prepends to every plugin shader module: WispGlobals, the sampler, the two input textures and the fullscreen-triangle vertex stage wisp_vs. Plugins must not redeclare anything in it.'
    },
    {
      tag: '06 / EXAMPLES',
      href: tree + 'examples',
      file: 'examples/',
      summary: 'Cross Dissolve (transition), Gaussian Blur (two passes with override constants) and Reactive Grade (a colour grade driven by signals). All pass naga and validate against the schema.'
    }
  ];
</script>

<svelte:head>
  <title>WISPFX.ORG — specification</title>
  <meta name="description" content="The WispFX specification: manifest, JSON schema, shader ABI, host prelude and reference plugins." />
</svelte:head>

<section class="hero">
  <div class="badge">DRAFT 0.1 · UNSTABLE</div>
  <h1 class="title">SPEC</h1>
  <div class="teaser">THE NORMATIVE TEXT LIVES IN spec/</div>
  <p class="lede">
    Anything may change before 1.0. Each file below is the source of truth for its chapter; this page is
    the map.
  </p>
</section>

<section class="section">
  <div class="sectionHeader">CORE DECISIONS · V0.1</div>
  <ul class="stack">
    <li><span>PLUGIN</span><span>one JSON manifest + one or more WGSL shaders</span></li>
    <li><span>KINDS</span><span>effect (1 input) · transition (2 inputs + progress 0..1)</span></li>
    <li><span>SPACE</span><span>linear, premultiplied RGBA, rgba16float</span></li>
    <li><span>PASSES</span><span>pipeline-overridable constants (override), set per pass in the manifest</span></li>
    <li><span>SIGNALS</span><span>MIDI 2.0 controllers and notes, one 0..1 float per signal per frame; the host maps audio, OSC and hardware onto them</span></li>
    <li><span>HOSTS</span><span>identical on native wgpu and browser WebGPU</span></li>
  </ul>
</section>

<section class="section">
  <div class="sectionHeader">FILES</div>
  <div class="grid files">
    {#each files as f (f.file)}
      <article class="card">
        <div class="cardTag">{f.tag}</div>
        <h2><a href={f.href} target="_blank" rel="noreferrer noopener">{f.file}</a></h2>
        <p>{f.summary}</p>
      </article>
    {/each}
  </div>
</section>

<section class="section">
  <div class="sectionHeader">CONFORMANCE</div>
  <p class="lede">
    A conforming host assembles each pass's module as the prelude plus the plugin's WGSL file, creates
    explicit pipeline layouts so unused bindings stay valid, provides the five bindings of group 0 and the
    plugin's Params at group 1, lays Params out with WGSL uniform alignment padded to 16 bytes, feeds linear
    premultiplied rgba16float in and out, drives progress across the clip or the cut, and accepts only WGSL
    that both naga and browser WebGPU compile.
  </p>
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
  .teaser {
    font-family: var(--font-display);
    font-weight: 300;
    font-size: clamp(0.85rem, 1.6vw, 1.1rem);
    letter-spacing: 0.32em;
    color: var(--text-muted);
    margin: 1.25rem 0 2.5rem;
  }
  .files {
    grid-template-columns: repeat(auto-fit, minmax(18rem, 1fr));
  }
  .card h2 a {
    color: var(--text);
    border-bottom: none;
    font-family: var(--font-mono);
    font-size: 1rem;
    letter-spacing: 0.04em;
  }
  .card h2 a:hover {
    color: var(--accent);
  }
</style>
