# Manifest — v0.1 (draft)

Every GoboFX plugin is a folder containing `manifest.json` and one or more `.wgsl` files.
Schema: [`manifest.schema.json`](manifest.schema.json).

## Top-level fields

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `gobofx` | string | yes | Spec version the plugin targets, e.g. `"0.1"` |
| `id` | string | yes | Reverse-DNS unique id, e.g. `org.gobofx.cross-dissolve` |
| `name` | string | yes | Display name |
| `kind` | `"effect"` \| `"transition"` \| `"generator"` | yes | Effect: 1 input. Transition: 2 inputs + `progress`. Generator: no input (added 2026-10-15) |
| `category` | string | no | Browser grouping: `dissolve`, `wipe`, `blur`, `color`, `distort`, `stylize`, … |
| `version` | string | yes | Plugin semver |
| `license` | string | no | SPDX expression |
| `params` | array | no | User-facing parameters (below) |
| `signals` | array | no | MIDI 2.0 controllers and notes the plugin reads each frame — see [`signals.md`](signals.md) |
| `assets` | array | no | Images shipped in the package a pass can read, e.g. a `.cube` LUT — see [`assets.md`](assets.md) (added 2026-10-17) |
| `passes` | array | yes | Render passes, executed in order (below) |

## Params

Params map, in declaration order, to the fields of the plugin's `Params` struct at `@group(1) @binding(0)`.
A plugin with no params declares no group 1.

| `type` | WGSL field | Value range / notes |
| --- | --- | --- |
| `float` | `f32` | `min`, `max`, `default`; optional `unit` (`px`, `deg`, `%`) |
| `int` | `i32` | `min`, `max`, `default` |
| `bool` | `u32` | 0 or 1 |
| `choice` | `u32` | index into `options: [string]` |
| `color` | `vec4f` | linear, premultiplied RGBA |
| `point` | `vec2f` | normalized uv, (0,0) top-left; host shows an onscreen handle |
| `asset` | — | an image the user picks (`kind`, optional `default` = a bundled asset id); **no struct field** — it is bound as a pass input by its id. See [`assets.md`](assets.md) |

The host lays the struct out with WGSL uniform alignment rules and pads it to a multiple of 16 bytes
(`asset` params are skipped: they are images, not values).
`animatable: true` (default) lets the host keyframe the param; it uploads the evaluated value per frame.

## Signals

Every plugin has a virtual MIDI 2.0 input. A signal binds a control change or a note on it; the host
turns audio followers, OSC or hardware into controller values and uploads one `f32` (0..1) per signal to
`@group(1) @binding(1)`, in declaration order. Full definition in [`signals.md`](signals.md).

## Passes

| Field | Meaning |
| --- | --- |
| `shader` | WGSL file, relative to the manifest |
| `entry` | Fragment entry point |
| `constants` | Values for `override` declarations, e.g. pass direction |
| `inputs` | 0–2 named images, bound to `gobofx_input0` / `gobofx_input1`. Only a generator pass may list none |
| `output` | Name of the image this pass writes; the last pass must write `out` |

Reserved input names: `source` (effects), `from` and `to` (transitions). A generator has none;
its first pass reads nothing and later passes read earlier outputs.
Any other name refers to an earlier pass's `output`, to a bundled asset (`assets[].id`) or to an
`asset` param (its id), see [`assets.md`](assets.md). Intermediate images are `rgba16float`, output-sized;
an asset keeps the size its kind defines.

## Assets

Images that are not frames: a `.cube` lookup table shipped in the package, or one the user picks
through an `asset` param. They bind as ordinary pass inputs, so the shader ABI does not change.
Full definition in [`assets.md`](assets.md).
