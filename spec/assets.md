# Assets — v0.1 (draft, added 2026-10-17)

An asset is an image a pass can read that is not a frame: a lookup table shipped
in the package, or one the user picks in the host. Assets are the way a LUT
plugin gets its `.cube` file, and the way a Looks pack ships fourteen grades
over one shader.

Design rule: **no new binding.** An asset is bound like any other pass input,
by name in `passes[].inputs`, into `gobofx_input0` / `gobofx_input1`. The
shader ABI, the prelude and every existing host stay as they are; an asset is
a `texture_2d<f32>` the host has decoded into a layout this document fixes.

## Manifest

```json
"assets": [
  { "id": "look", "kind": "lut3d", "file": "look.cube" }
]
```

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `id` | string | yes | `^[a-z_][a-z0-9_]*$`, unique among assets, params and signals. The name a pass lists in `inputs` |
| `kind` | `"lut3d"` | yes | The asset's format (below). v0.1 defines only `lut3d`; `image` is reserved |
| `file` | string | yes | Package entry, relative to the manifest, no `..`. Extension per kind (`.cube`) |
| `label` | string | no | Display name |

Rules:

- A pass that lists an asset id in `inputs` gets that asset bound at the
  listed position. `["source", "look"]` binds the frame to `gobofx_input0`
  and the LUT to `gobofx_input1`. Every other input rule of
  [`manifest.md`](manifest.md) still holds: 0–2 inputs, reserved names, earlier
  outputs.
- An asset id MUST NOT be used as a pass `output`.
- The host decodes the file once when the plugin loads and keeps the texture
  for the plugin's lifetime. It is never re-read per frame.
- A host MUST reject a package whose asset file is missing, unparseable or over
  the kind's size limit, with the rule that failed.

## The `asset` param type

A bundled asset is fixed. For an asset the user chooses, declare a param of
type `asset`:

```json
"params": [
  { "id": "lut", "type": "asset", "kind": "lut3d", "default": "look" }
]
```

| Field | Meaning |
| --- | --- |
| `kind` | required; the asset kind the param accepts |
| `default` | optional; the id of a bundled asset used until the user picks one |

- An `asset` param is an image, not a number: it takes **no field in the
  `Params` uniform struct**. The declaration-order mapping of
  [`manifest.md`](manifest.md) skips it.
- Its id is an input name: `inputs: ["source", "lut"]` binds whatever the
  param currently resolves to. The host resolves, in order: the user's choice
  (a host asset — a file in the project, an item from a library), else the
  bundled `default`, else nothing.
- **Nothing** is the 1×1 transparent texture the prelude already uses for an
  unbound input. The plugin MUST treat it as "no asset" and pass the picture
  through unchanged; `textureDimensions(gobofx_input1).y == 1u` is the test.
- `animatable` is ignored for `asset` params. Hosts MAY keyframe the choice as
  a stepped lane; v0.1 does not require it.
- The stored value of an `asset` param is host-defined (an asset id, a path, a
  hash). It never appears in the package.
- A host with no asset library (the reference CLI, a minimal player) MAY offer
  only the bundled assets, or load a file from a path.

## `lut3d` — a 3D colour lookup table

### Source format

The Adobe/IRIDAS `.cube` text format, as used by every grading tool:

- Optional `TITLE "…"`.
- `LUT_3D_SIZE N`, `2 ≤ N ≤ 65`.
- Optional `DOMAIN_MIN r g b` and `DOMAIN_MAX r g b`. v0.1 supports only the
  default domain `0 0 0` / `1 1 1`; a host MUST reject any other domain.
- `N³` lines of three floats, **red fastest, then green, then blue**:
  entry `(r, g, b)` at line `r + N·g + N²·b`.
- Lines starting with `#` are comments; blank lines are ignored. Values may
  exceed 0..1 (an HDR grade); hosts keep them.
- `LUT_1D_SIZE` (a 1D LUT) is not an asset kind in v0.1; a host MUST reject it.

### Texture layout — the strip

The host decodes the lattice into a 2D `rgba16float` texture, alpha 1, laid
out as **N tiles of N×N side by side**:

- texture size `(N·N) × N`;
- tile `b` (blue index, 0..N−1) spans columns `b·N … b·N + N−1`;
- within a tile, column = red index, row = green index;
- texel `(b·N + r, g)` = the lattice entry `(r, g, b)`.

The texture is bound with the standard `gobofx_sampler` (linear,
clamp-to-edge). Bilinear filtering inside a tile interpolates red and green
exactly; the shader interpolates blue by sampling the two neighbouring tiles
and mixing. That is a full trilinear lookup with two taps.

### Reference lookup

The plugin reads `N` from the texture: `textureDimensions(gobofx_input1).y`.

```wgsl
// c: straight (unpremultiplied) colour in the LUT's input space, 0..1.
fn lut3d_sample(lut: texture_2d<f32>, c: vec3f) -> vec3f {
    let dims = textureDimensions(lut);
    if (dims.y <= 1u) { return c; }           // nothing bound: identity
    let n = f32(dims.y);
    let x = clamp(c, vec3f(0.0), vec3f(1.0)) * (n - 1.0);
    let b0 = floor(x.b);
    let b1 = min(b0 + 1.0, n - 1.0);
    let fb = x.b - b0;
    // Texel centres: + 0.5, divided by the texture size.
    let uv0 = vec2f((b0 * n + x.r + 0.5) / (n * n), (x.g + 0.5) / n);
    let uv1 = vec2f((b1 * n + x.r + 0.5) / (n * n), (x.g + 0.5) / n);
    let s0 = textureSampleLevel(lut, gobofx_sampler, uv0, 0.0).rgb;
    let s1 = textureSampleLevel(lut, gobofx_sampler, uv1, 0.0).rgb;
    return mix(s0, s1, fb);
}
```

A host MAY add this function to a later prelude; in v0.1 the plugin carries
it.

### Colour space

The working space is linear, premultiplied Rec. 709
([`shader-abi.md`](shader-abi.md)). Almost every `.cube` is authored for an
encoded input — display sRGB/Rec. 709 (gamma), or a camera log curve — so a
LUT plugin:

1. unpremultiplies,
2. encodes linear → the LUT's input space (`input_space` param: `srgb`,
   `linear`; a log curve is the plugin's business),
3. looks up,
4. decodes back to linear and premultiplies,
5. optionally mixes with the original by an `intensity` param.

The spec fixes none of this beyond the working space; it is the plugin's
documented behaviour. Hosts MUST NOT convert LUT data.

### Limits

- `N ≤ 65`: a 65³ strip is 4225×65 texels, 2.2 MB as `rgba16float`.
- At most 16 `lut3d` assets per package; a Looks pack beyond that splits.
- `.cube` entries deflate well; a package SHOULD still keep LUT entries under
  8 MiB total.

## Package

`assets[].file` entries are allowed content ([`package.md`](package.md)). The
same name rules apply as to shaders: an entry a pass can reach only through
the manifest, never by scanning.

## Validation (tools)

1. Every `assets[].file` resolves to an entry; extension matches the kind.
2. Each `.cube` parses: size in range, default domain, exactly `N³` triplets.
3. Asset ids are unique and collide with no param or signal id.
4. Every `asset` param's `kind` is a defined kind and its `default`, when
   present, names a bundled asset of that kind.
5. Every pass input that is neither reserved nor an earlier output is an asset
   id or an `asset` param id; no asset name is a pass output.
6. The `Params` struct skips `asset` params (count, types, offsets).

## Open for a later revision

- `image` assets (textures for grain, scratches, glass, leaves): same binding
  model, PNG/WebP entries, sampled as ordinary 2D textures.
- `lut1d` and non-default domains.
- Presets over a plugin (`presets[]`), which is how a Looks pack names its
  LUTs in the host's browser.
