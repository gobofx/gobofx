# Aura

A soft halo in one colour around the alpha shape, on both sides of its
edge: the light peaks on the outline and dies away outward into the
transparent area and inward into the fill, which stays untouched at its
heart. Intensity 0 is a no-op.

- **Radius** — spread in pixels (1 to 64); the halo reaches about this far past the edge.
- **Intensity** — strength; above 1 the rim saturates to a solid line of colour.
- **Color** — the halo's colour; its alpha scales the whole halo.

## Use it when

- A title, a logo or a cut-out subject on transparency should sit in its own
  light rather than on a hard edge.
- A keyed subject needs a rim that reads as light wrap, in the colour of the
  background it is going over.
- A ghost, a saint or an energy shield: a halo that glows through the shape
  as much as around it.

## Avoid when

- The halo should stay strictly outside the shape and leave the fill alone:
  that is Outer Glow.
- The source has no alpha: a full-frame picture has no edge to light, so
  nothing appears; use Glow or Bloom on the highlights instead.
- Thin text at a large radius: the letters fill in and the halo swallows the
  counters.
