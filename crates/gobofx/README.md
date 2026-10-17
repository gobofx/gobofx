# gobofx — reference crate, test CLI and browser host

One crate, three targets: the `gobofx` CLI on macOS, Windows and Linux (Metal,
DX12, Vulkan), and the same host compiled to WebAssembly for the browser on
WebGPU, which powers the play page at gobofx.org/play. Validation, module
assembly, parameter layout and the pass pipeline are identical on all of them.

Validates and renders GoboFX plugins headlessly, with no host application. Made
for people and for agents: every command has a `--json` form, exit codes are
meaningful (0 ok, 1 the plugin failed, 2 bad usage), and `render` writes PNGs.

```sh
cargo build -p gobofx --release          # binary at target/release/gobofx

gobofx check  spec/examples/gaussian-blur            # manifest rules + naga, per pass
gobofx check  spec/examples/gaussian-blur --json     # same, machine-readable
gobofx info   spec/examples/gaussian-blur            # manifest, params layout, passes

gobofx render spec/examples/gaussian-blur  -i fixtures/a.png -p radius=12 -o blur.png
gobofx render spec/examples/cross-dissolve -i fixtures/a.png -i fixtures/b.png --steps 9 --out-dir frames
gobofx render spec/examples/reactive-grade  -i fixtures/a.png -s bass=1 -s flash=1 -o grade.png
```

- Effects take one `-i` (source); transitions take two (from, then to).
- `--progress` sets the transition position (or the position across the clip
  for an effect); `--steps N` renders N frames from 0 to 1 instead.
- `--param id=value` overrides a manifest default: floats and ints as numbers,
  bools `true`/`false`, choices by index or option name, colors `r,g,b,a`,
  points `x,y`.
- `--signal id=value` sets a signal (a MIDI 2.0 controller or note level) to a
  fixed 0..1 value for the frame, so a reactive plugin can be tested without MIDI.
- `--asset id=path.cube` fills an `asset` param with a file from disk, the way a
  host's picker would (`spec/assets.md`); without it the param's bundled default
  applies. `-p id=none` binds nothing, which a plugin must treat as identity.
- Inputs are PNGs (sRGB, straight alpha). They are converted to the working
  space from `spec/shader-abi.md` (linear, premultiplied, rgba16float) on upload
  and back for the output PNG.
- The prelude is embedded from `spec/prelude.wgsl`, so the CLI and a host built
  on this crate assemble byte-identical modules.

`fixtures/a.png` and `fixtures/b.png` are small test images (256×144) with
distinct shapes, so a transition's direction and an effect's spatial behaviour
are visible at a glance.

## `gobofx verify` — the agent-driven check

```sh
source tools/gpu-env.sh                                   # Linux without a GPU: SwiftShader
gobofx verify plugins/org.gobofx.wipe                     # one plugin
gobofx verify plugins/org.gobofx.*/ --json                # the library; index.json + all.png
gobofx verify plugins/org.gobofx.wipe --assets            # also write preview.png + icon.png
tools/verify-all.sh                                       # build + verify everything
```

`verify` derives a case matrix from the manifest — defaults, a repeat, a later
`time`, transition progress 0 / .25 / .5 / .75 / 1, every param at its min, max
or each option (and once more over each signal level), every signal alone and
against the others — renders each case to `<dir>/dist/verify/<case>.png`, and
checks:

| check | fails when |
|---|---|
| `validate`, `compile` | the manifest or a shader is rejected (naga, then the GPU) |
| `finite`, `alpha-range` | a pixel is NaN/Inf or alpha leaves 0..1 (checked on the rgba16float target, before PNG clamping) |
| `premultiplied` (warn) | colour exceeds alpha on partially transparent pixels |
| `endpoint:0`, `endpoint:1` | a transition at progress 0 isn't `from`, at 1 isn't `to` (max 3/255) |
| `progression` (warn) | the picture moves back towards `from` as progress grows |
| `live:<param>` | changing the param leaves the render untouched (unused field, wrong `Params` order, inert default) |
| `identity` | the `verify.json` identity params don't reproduce the source |
| `not-blank` | the default render is fully transparent or one flat colour |
| `deterministic` | rendering twice gives different bytes |
| `perf` (warn) | 1280×720 takes over 250 ms on a hardware adapter |

`report.json` holds every case and check; `sheet.png` is a labelled contact
sheet of the inputs and every case, drawn so it can be read without a viewer
that shows file names. Several plugins at once also write
`dist/verify/index.json` and `all.png` (one status-coloured cell per plugin).
Exit code 1 if any check fails.

`asset` params are swept over every other bundled asset of their kind and over
"none"; bundled `.cube` files are parsed and uploaded as the strip texture the
spec fixes, so a LUT plugin verifies like any other.

Optional `plugins/<id>/verify.json` (not packed): `{"source": "green" | "alpha"}`
picks the keying or the transparent fixture for `source`; `"inert": [ids]`
exempts params that cannot move the default render; `"identity": {id: text}`
asks for an identity check under those params; `"flat": true` accepts a flat
default render (a solid generator).

No GPU on a Linux box? `source tools/gpu-env.sh` points the Vulkan loader at
the SwiftShader that ships with Playwright's Chromium (or `$SWIFTSHADER_DIR`).
Renders are bit-exact to the host's rules, just slow (a 720p blur ≈ 0.7 s).

## Browser build

```sh
cd apps/site && pnpm run build:wasm      # cargo build for wasm32 + wasm-bindgen → src/lib/wasm/
```

The `web` module (`src/web.rs`, wasm32 only) exposes `create_host(canvas)` and a
`WebHost` with `load_plugin`, `set_video`, `resize` and `render`. The page owns the
`<video>` elements and the signal values; the crate owns everything GPU. The
wasm-bindgen family is pinned to the installed CLI version (0.2.113).
