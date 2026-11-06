# Soft Focus

A diffusion filter rather than a blur: a soft copy of the picture is
screened over the sharp one, so the lights bloom and the midtones go milky
while the detail stays underneath. Amount 0 is a no-op.

- **Radius** — spread of the diffusion in pixels (up to 64).
- **Amount** — how much of the diffused copy shows over the sharp picture, 0..1.
- **Highlights** — 0 diffuses evenly, 1 lifts only the brights; the midpoint is a mist filter.

## Use it when

- A beauty or romance pass: skin softens and catchlights glow while the
  eyes stay sharp.
- A period look, the glamour close-up shot through a net or a smear of
  grease on the lens.
- Dreams, memories and flashbacks, animated in from 0 on the cut.

## Avoid when

- The picture should actually be out of focus: Gaussian Blur or Defocus.
- Only the brights should bleed, with no lift in the midtones: that is
  Glow or Bloom.
- Night exteriors and low-key scenes: the milk flattens the blacks and the
  mood goes with them.
