# Noise

Procedural noise as a texture: value noise, Perlin (gradient) noise, or
cellular (Worley) cells, stacked as up to six fBm octaves and drifting with
time. Zero to one is mapped onto two colours, so it doubles as a mask source.

- **Style** — value (soft blobs), perlin (smoother, directional), cellular
  (cells with bright centres).
- **Scale** — cells across the frame height. **Octaves** — detail layers.
- **Speed** — drift per second; 0 freezes it.
- **Contrast** — 1 is linear; higher pushes towards the two colours.
- **Dark / Light** — the colours at 0 and 1, with alpha.
