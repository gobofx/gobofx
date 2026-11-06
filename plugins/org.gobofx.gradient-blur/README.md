# Gradient Blur

A tilt-shift ramp: one sharp band across the frame and a Gaussian blur that
grows with distance from it, so a scene reads as a miniature or the eye is
held on one strip. Radius 0 is a no-op.

- **Band Position** — where the sharp band sits along the axis, 0 one edge to 1 the other.
- **Band Width** — the sharp zone, as a fraction of the frame.
- **Feather** — how far past the band the blur ramps to full.
- **Radius** — the blur radius in pixels reached past the feather (up to 48).
- **Angle** — tilt of the band in degrees; 0 is horizontal.

## Use it when

- A wide shot of a city, a crowd or a road should feel like a model: narrow
  band, short feather, full radius.
- A lower third or caption needs the plate quiet above and below it while
  the subject's row stays sharp.
- A still or drone frame needs implied depth that the lens never gave it.

## Avoid when

- The band crosses a face or a moving subject: a tilt-shift on people reads
  as a mistake unless the subject sits inside the band.
- You need a true depth-of-field falloff around one object rather than a
  strip: use Defocus with a mask.
- The blur should follow a point rather than a line: Radial Blur or Zoom
  Blur centre on a point.
