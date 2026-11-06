# Noise Dissolve

Eat the picture away to transparent through a field of random grains.
**Amount** is the fraction gone: keyframe it from 0 to 1 and the clip
dissolves into whatever is underneath, grain by grain, like a sand
painting blowing away. **Amount** 0 returns the source untouched.

- **Amount** — 0 is the source, 1 is fully transparent; animate this.
- **Grain Size** — in pixels; 1 is fine static, 8+ is visible blocks.
- **Softness** — 0 cuts each grain at once, 1 fades every grain across the whole move.
- **Seed** — a different grain field; change it so two dissolves in a row do not match.

## Use it when

- A layer should disintegrate rather than fade: a title that blows away, a ghost that scatters.
- A gritty, lo-fi reveal or exit over a texture or a background plate, at a small grain.
- A transparent-layer exit where a crossfade would look too clean, in a piece that is already textured.

## Avoid when

- A plain, elegant fade is wanted; the grain always looks deliberate. Use Cross Dissolve or an opacity keyframe.
- You are dissolving between two clips on one track; this is an effect on one layer, so use a Dissolve transition.
- The clip will be heavily compressed afterwards; a fine, half-dissolved grain is the worst case for an encoder.
