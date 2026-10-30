# Grading params — `wheel` and `curve` (v0.2 draft)

> **Status: draft proposal, not part of v0.1.** Two param types for color
> grading plugins: a color wheel (lift / gamma / gain / offset style) and a
> baked curve (custom RGB curves, hue-vs-hue, hue-vs-sat, luma-vs-sat). A
> plugin that uses either declares `"gobofx": "0.2"`. A v0.1 host rejects it
> as an unknown param type, which is the intended failure: a grade that
> renders without its wheels is wrong, not degraded.

Both types follow the same rule as every other param: **the stored value fully
determines the pixels.** Widgets are free per host; what the document holds,
and how it reaches the shader, is fixed here so the same plugin and value
render the same everywhere.

## `wheel`

| `type` | WGSL field | Value |
| --- | --- | --- |
| `wheel` | `vec4f` | `[r, g, b, master]` |

- **`xyz` — balance.** A per-channel offset that changes hue without changing
  brightness: it is **luma-neutral** under the Rec. 709 weights of the working
  space ([`shader-abi.md`](shader-abi.md) "Color"),
  `0.2126·r + 0.7152·g + 0.0722·b = 0`. The default balance is `[0, 0, 0]`.
- **`w` — master.** Behaves like a `float` param: `min`, `max`, `default` (a
  number) apply to it.
- **`range`** (optional, default `1.0`, > 0) bounds the balance: every
  component lies in `[-range, range]`.

What the four numbers *mean* is the plugin's: a primaries plugin reads one
wheel as lift, another as gain. The type fixes only storage and constraints.

### Keeping the balance valid

After every edit the host normalizes the balance `p`, in this order:

1. **Project** onto the luma-neutral plane:
   `p ← p − (W·p / W·W) · W`, with `W = (0.2126, 0.7152, 0.0722)`.
2. **Bound** by uniform scaling: if `max(|p.x|, |p.y|, |p.z|) > range`,
   `p ← p · range / max(|p.x|, |p.y|, |p.z|)`. Scaling keeps the projection
   valid; clamping per component would not.

A host loading a document whose balance violates either rule normalizes it the
same way before rendering, so a hand-edited or foreign value still renders
deterministically.

### Animation

The four components animate independently in stored space. The luma-neutral
plane is linear, so interpolating two valid balances stays valid, and no
re-projection is needed between keyframes.

### Widget (non-normative)

The natural widget is a disc with a puck for the balance and a ring or slider
for the master; double-click resets. Orienting the disc like a vectorscope (the
puck moves toward the hue it adds) is recommended. Because the stored value is
RGB, hosts may map puck travel to balance differently: that changes how a drag
*feels*, not what a given value renders. A host without a wheel widget shows
three balance sliders, which are normalized on commit, and one master slider.

## `curve`

| `type` | WGSL field | Value |
| --- | --- | --- |
| `curve` | none, bound as an image | 1–4 point lists |

A curve param takes **no field in `Params`.** The host bakes it into a strip
texture, and the param's `id` is usable as a pass input name, bound to
`gobofx_input0` or `gobofx_input1` like an earlier pass's output.

### Declaration

| Field | Required | Meaning |
| --- | --- | --- |
| `channels` | yes | 1–4 labels, e.g. `["Red", "Green", "Blue", "Luma"]`. Curve *k* bakes into strip channel *k* (r, g, b, a) |
| `periodic` | no | `false` (default): x in `[0, 1]`, ends extend flat. `true`: x wraps at 1, for hue axes |
| `min`, `max` | no | y range, default `0`..`1`. Baked values are clamped to it |
| `samples` | no | Strip width in texels: 16..4096, default `256` |
| `default` | see below | One point list per channel |

A non-periodic channel without a `default` is the identity line
`[[0, 0], [1, 1]]`. A periodic channel has no natural identity, so its
`default` is required (a hue-vs-sat curve is typically the flat line
`[[0, 0.5]]`, which the plugin reads as "×1").

### Value

`[[[x, y], …], …]` — one list per declared channel, in `channels` order.

- x strictly increasing. Non-periodic: x in `[0, 1]`, 2..16 points.
  Periodic: x in `[0, 1)`, 1..16 points; a point at 0 is not repeated at 1.
- y in `[min, max]`.
- `animatable` must be `false` (the default for this type): two curves with
  different point counts have no defined in-between.

### Bake (normative)

Every host bakes identically. Arithmetic is IEEE-754 binary32 in the order
written. A JavaScript host rounds each operation with `Math.fround`. The result
is stored as `rgba16float`, rounded to nearest-even.

For each channel, with points `(x_k, y_k)`, `k = 0..n−1`:

1. **Intervals and secants.** `h_k = x_{k+1} − x_k`,
   `d_k = (y_{k+1} − y_k) / h_k`. A periodic channel continues cyclically:
   index `n` is point 0 with `x + 1`, and index `−1` is point `n−1` with
   `x − 1`.
2. **Tangents** (shape-preserving piecewise cubic Hermite, weighted harmonic
   mean). For each interior point:
   - `m_k = 0` if `d_{k−1} = 0`, `d_k = 0`, or they differ in sign;
   - otherwise, with `w1 = 2·h_k + h_{k−1}` and `w2 = h_k + 2·h_{k−1}`:
     `m_k = (w1 + w2) / (w1 / d_{k−1} + w2 / d_k)`.

   Non-periodic endpoints use their one secant: `m_0 = d_0`,
   `m_{n−1} = d_{n−2}`. Every point of a periodic channel is interior.
3. **Evaluate** at `x`. Non-periodic: `x ≤ x_0` gives `y_0` and
   `x ≥ x_{n−1}` gives `y_{n−1}`. Periodic: `x` is taken modulo 1; a single
   point gives the constant `y_0`. Otherwise find `k` with
   `x_k ≤ x < x_{k+1}`, let `t = (x − x_k) / h_k`, and
   `y = (2t³ − 3t² + 1)·y_k + (t³ − 2t² + t)·h_k·m_k + (−2t³ + 3t²)·y_{k+1} + (t³ − t²)·h_k·m_{k+1}`.
4. **Clamp** `y` to `[min, max]`.

Texel `i` (`0..samples−1`) holds `curve(i / (samples − 1))` in each declared
channel and `0` in the rest. The strip is `samples × 1`. The first and last
texels sit exactly on x = 0 and x = 1, which for a periodic channel are the
same value.

The tangent rule never overshoots: between two points the curve stays between
their y values, so a curve the user drew monotone stays monotone.

### Reading a strip

Read strips through the prelude's `gobofx_curve`. It samples at texel
**centres** — `x·(N−1)/N + 0.5/N` — so x = 0 and x = 1 hit the first and last
baked samples exactly and linear filtering interpolates only between neighbours.
Sampling the raw `x` would read half a texel off the baked curve. A periodic
plugin passes `fract(x)`.

```wgsl
// One RGB-curves pass: inputs ["source", "rgb_curve"].
@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let c = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let a = max(c.a, 1e-6);
    let rgb = c.rgb / a; // curves act on straight color
    let out = vec3f(
        gobofx_curve(gobofx_input1, rgb.r).r,
        gobofx_curve(gobofx_input1, rgb.g).g,
        gobofx_curve(gobofx_input1, rgb.b).b,
    );
    return vec4f(out * c.a, c.a);
}
```

### Limits

A pass reads at most two images, so an effect pass has room for one strip
next to `source`. That is why one `curve` param carries up to four curves:
RGB + luma fit in one pass. More curves (the hue curves next to RGB) take a
second pass or a second plugin.

## Manifest example (non-normative)

```json
{
  "gobofx": "0.2",
  "id": "org.gobofx.primaries",
  "name": "Primaries",
  "kind": "effect",
  "category": "color",
  "version": "0.1.0",
  "params": [
    { "id": "lift",  "label": "Lift",  "type": "wheel", "default": 0.0, "min": -1.0, "max": 1.0, "range": 0.5 },
    { "id": "gamma", "label": "Gamma", "type": "wheel", "default": 0.0, "min": -1.0, "max": 1.0, "range": 0.5 },
    { "id": "gain",  "label": "Gain",  "type": "wheel", "default": 1.0, "min": 0.0,  "max": 4.0, "range": 1.0 },
    { "id": "rgb_curve", "label": "Curves", "type": "curve", "channels": ["Red", "Green", "Blue", "Luma"] }
  ],
  "passes": [
    { "shader": "primaries.wgsl", "entry": "fs_main", "inputs": ["source"], "output": "balanced" },
    { "shader": "curves.wgsl",    "entry": "fs_main", "inputs": ["balanced", "rgb_curve"], "output": "out" }
  ]
}
```

## Open questions

- **Log working space for wheels.** Lift/gamma/gain are usually applied in a
  log encoding of the linear working space. The plugin does that conversion
  today; a shared `gobofx_lin_to_log` / `gobofx_log_to_lin` pair in the
  prelude would make plugins agree on the curve.
- **Wheel defaults beyond the master.** The balance default is fixed at zero.
  No use case for a non-zero default balance has come up yet.
- **`samples` above 4096.** 8192 is the guaranteed WebGPU 2D limit; 4096
  leaves headroom. Raise it if a real curve needs more resolution.
