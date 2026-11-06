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

## Use it when

- Texture under titles, with **Light** alpha at 0 so only the dark shows.
- A matte source for other effects: displacement, a luma key, an animated
  wipe edge.
- Fog, smoke or clouds behind a key, with cellular style and slow **Speed**.

## Avoid when

- As the picture. It is a bed or a matte.
- Grain over footage. Use Film Grain; it knows about shadows and frame
  renewal.
- High **Octaves** on compressed delivery. The detail becomes blocking.
