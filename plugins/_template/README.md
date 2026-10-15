# Plugin templates

One starting point per kind. Each is a complete, valid, deliberately boring
plugin that shows every piece of the interface a plugin implements: the
manifest, the `Params` struct, the `Signals` struct, the fragment entry
points, multi-pass with `override` constants, and how to read what the host
provides.

| Folder | Kind | Inputs | Does |
| --- | --- | --- | --- |
| [`effect/`](effect/) | `effect` | `source` | tint + posterize, then a vignette (two passes, one `override`), every param type, one signal |
| [`transition/`](transition/) | `transition` | `from`, `to` + `progress` | soft-edged directional wipe, one signal |
| [`generator/`](generator/) | `generator` | none | a shape over a background colour, one note signal |

## Start a plugin

1. Copy the variant for your kind to `plugins/<your.id>/` (or anywhere; the
   folder name should equal `manifest.id`).
2. In `manifest.json` set `id` (reverse-DNS under your own namespace),
   `name`, `category`, `version`, `license`.
3. Edit the shader. Keep `Params`/`Signals` fields in manifest order; the
   validator checks the types and order against the manifest.
4. Validate: `cargo run -p gobofx -- check plugins/<your.id>`
5. Render a frame: `cargo run -p gobofx -- render plugins/<your.id> -i in.png`
   (two `-i` for a transition, none for a generator).
6. Replace `icon.png` (square, 128×128) and add `preview.png` (≤ 512×512,
   16:9); write `README.md`. Hosts show all three: the icon in lists and on
   timeline items, the preview in the browser, the README as the description.

What the host provides is declared in [`spec/prelude.wgsl`](../../spec/prelude.wgsl)
and prepended to your shader; never redeclare it. The full interface is in
[`spec/shader-abi.md`](../../spec/shader-abi.md), params and passes in
[`spec/manifest.md`](../../spec/manifest.md), signals in
[`spec/signals.md`](../../spec/signals.md).
