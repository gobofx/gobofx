# wispfx — reference crate and test CLI

Validates and renders WispFX plugins headlessly, with no host application. Made
for people and for agents: every command has a `--json` form, exit codes are
meaningful (0 ok, 1 the plugin failed, 2 bad usage), and `render` writes PNGs.

```sh
cargo build -p wispfx --release          # binary at target/release/wispfx

wispfx check  spec/examples/gaussian-blur            # manifest rules + naga, per pass
wispfx check  spec/examples/gaussian-blur --json     # same, machine-readable
wispfx info   spec/examples/gaussian-blur            # manifest, params layout, passes

wispfx render spec/examples/gaussian-blur  -i fixtures/a.png -p radius=12 -o blur.png
wispfx render spec/examples/cross-dissolve -i fixtures/a.png -i fixtures/b.png --steps 9 --out-dir frames
```

- Effects take one `-i` (source); transitions take two (from, then to).
- `--progress` sets the transition position (or the position across the clip
  for an effect); `--steps N` renders N frames from 0 to 1 instead.
- `--param id=value` overrides a manifest default: floats and ints as numbers,
  bools `true`/`false`, choices by index or option name, colors `r,g,b,a`,
  points `x,y`.
- Inputs are PNGs (sRGB, straight alpha). They are converted to the working
  space from `spec/shader-abi.md` (linear, premultiplied, rgba16float) on upload
  and back for the output PNG.
- The prelude is embedded from `spec/prelude.wgsl`, so the CLI and a host built
  on this crate assemble byte-identical modules.

`fixtures/a.png` and `fixtures/b.png` are small test images (256×144) with
distinct shapes, so a transition's direction and an effect's spatial behaviour
are visible at a glance.
