# Ring Lens

A lens shaped like a ring: between the inner and the outer radius the
picture is magnified towards the ring's midline, while the middle and the
outside stay as they were, with no seam at either edge. A negative Amount
shrinks the ring instead. At Amount 0 the picture passes through unchanged.
Pixels pulled from outside the frame repeat the edge.

- **Center** — the ring's centre.
- **Inner Radius** — in frame heights; 0 closes the hole and the ring becomes a disc.
- **Outer Radius** — in frame heights; kept just above the inner radius.
- **Amount** — 1 a full magnifying ring, -1 a full shrinking one; 0 is a no-op.

## Use it when

- A halo, a shockwave or a pulse travelling out from a point: keyframe both
  radii outward together with Amount fading to 0.
- Dressing a lens, a ring light or a glass rim in a composite, centred on
  the prop.
- Framing a subject by leaving it untouched in the hole and bending the
  surroundings around it.

## Avoid when

- A single dome is what you mean: use Bulge, which puts its peak in the
  middle.
- Faces across the ring's width; features inside the band stretch while the
  centre of the face does not.
- The ring runs through text or a graphic's straight edges.
