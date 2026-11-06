# GoboFX Specification

Status: **draft 0.1, unstable** — anything may change before 1.0.

| File | Contents |
| --- | --- |
| [`manifest.md`](manifest.md) | Plugin manifest: kind, params, passes |
| [`manifest.schema.json`](manifest.schema.json) | JSON Schema for the manifest |
| [`shader-abi.md`](shader-abi.md) | WGSL interface: bindings, entry point, color space |
| [`signals.md`](signals.md) | Signals: MIDI 2.0 controllers, notes, note ranges, pitch bend and pressure the plugin reads each frame; the host maps audio, OSC and hardware onto them |
| [`assets.md`](assets.md) | Assets: `.cube` lookup tables shipped in the package or picked by the user, bound as pass inputs in a fixed strip layout; the `asset` param type |
| [`package.md`](package.md) | Package format: the `.gobofx` ZIP profile a plugin folder is distributed as |
| [`prelude.wgsl`](prelude.wgsl) | Host prelude prepended to every plugin shader |
| [`../plugins/_template/`](../plugins/_template/) | Starting points: one complete, valid plugin per kind, every interface piece shown |
| [`examples/`](examples/) | Reference plugins: Cross Dissolve (transition), Gaussian Blur (2-pass effect), Reactive Grade, Chromatic Hue and Kaleidoscope (effects played over MIDI signals) |

## Core decisions (v0.1)

- One plugin = a JSON manifest + one or more WGSL shaders, in a folder; distributed as a `.gobofx` ZIP (strict profile).
- Three kinds: `effect` (1 input), `transition` (2 inputs + `progress` 0..1) and `generator` (no input).
- Working space: linear, premultiplied RGBA, `rgba16float`.
- Multi-pass via pipeline-overridable constants (`override`), set per pass in the manifest.
- Signals: a plugin declares MIDI 2.0 controllers and notes it reacts to; the host maps audio followers, OSC and hardware onto them and delivers one 0..1 float per signal per frame.
- Runs identically on native wgpu and browser WebGPU.
