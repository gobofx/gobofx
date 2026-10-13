# WispFX Specification

Status: **draft 0.1, unstable** — anything may change before 1.0.

| File | Contents |
| --- | --- |
| [`manifest.md`](manifest.md) | Plugin manifest: kind, params, passes |
| [`manifest.schema.json`](manifest.schema.json) | JSON Schema for the manifest |
| [`shader-abi.md`](shader-abi.md) | WGSL interface: bindings, entry point, color space |
| [`prelude.wgsl`](prelude.wgsl) | Host prelude prepended to every plugin shader |
| [`examples/`](examples/) | Reference plugins: Cross Dissolve (transition), Gaussian Blur (2-pass effect) |

## Core decisions (v0.1)

- One plugin = a JSON manifest + one or more WGSL shaders.
- Two kinds: `effect` (1 input) and `transition` (2 inputs + `progress` 0..1).
- Working space: linear, premultiplied RGBA, `rgba16float`.
- Multi-pass via pipeline-overridable constants (`override`), set per pass in the manifest.
- Runs identically on native wgpu and browser WebGPU.
