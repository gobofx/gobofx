# Shader ABI — v0.1 (draft)

## Module assembly

The host builds each pass's shader module as `prelude.wgsl` + the plugin's `.wgsl` file.
The prelude declares all host bindings and the vertex stage (`wisp_vs`); plugins write only fragment code.
The host creates pipeline layouts explicitly, so unused bindings stay valid.

## Bindings

| Group | Binding | Name | Type |
| --- | --- | --- | --- |
| 0 | 0 | `wisp_sampler` | `sampler` — linear, clamp-to-edge |
| 0 | 1 | `wisp_globals` | `uniform WispGlobals` — resolution, texel, time, progress |
| 0 | 2 | `wisp_input0` | `texture_2d<f32>` — first pass input |
| 0 | 3 | `wisp_input1` | `texture_2d<f32>` — second pass input, or 1×1 transparent |
| 1 | 0 | `params` | `uniform Params` — declared by the plugin, matches the manifest `params` |
| 1 | 1 | `wisp_signals` | `uniform Signals` — declared by the plugin, one `f32` per manifest signal ([`signals.md`](signals.md)) |

## Fragment entry

```wgsl
@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f
```

`uv` is (0,0) at the top-left. Sample with `textureSampleLevel(…, 0.0)` so sampling is legal in non-uniform control flow.

## Color

All inputs and outputs are **linear, premultiplied RGBA** in `rgba16float`, Rec. 709 primaries.
Values above 1.0 are allowed (HDR). The host converts to and from display/encode spaces.

## Portability rules

- WGSL only as accepted by both wgpu (naga) and browser WebGPU; no extensions in v0.1.
- No storage textures, no compute, no texture arrays in v0.1.
- Loops must be bounded by a constant or by a param clamped to a constant.
