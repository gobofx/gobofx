# Neon

The edges of the picture become glowing tubes: edges are detected, drawn in
one colour with a soft halo, and laid over a darkened copy of the source,
so a face or a skyline turns into a neon sign of itself. Intensity 0 with
Darken 0 is a no-op.

- **Color** — the tube's colour; its alpha scales tube and halo together.
- **Radius** — halo spread in pixels (1 to 64); the tube itself stays one pixel crisp.
- **Intensity** — strength of tube and halo; above 1 the tube goes white-hot at its core.
- **Darken** — how far the source is dimmed underneath, 0 to 1; 1 leaves only the tubes.

## Use it when

- A title sequence, a music video or a club scene wants the picture as a
  neon sign: outlines in pink or cyan on near-black.
- A graphic, a logo or a line drawing should light up as if it were tubing;
  keyframe the intensity for a flicker-on.
- An eighties, synthwave or arcade cue, where the look is the point.

## Avoid when

- Noisy or grainy footage: every grain is an edge and the tubes fill with
  fizz; denoise or blur first.
- Anything that must still read as the original image; at the default
  darken the picture is gone and only its contours remain.
- A plain outline without the glow is wanted: an edge-detect effect does
  that without the halo and the darkening.
