# Bevel

A lit edge on the alpha shape: a soft slope rising from the outline inward,
bright on the side that faces the light and dark on the side that does not,
so a title or a cut-out reads as a solid object. Width 0 is a no-op.

- **Width** — how far the slope reaches inside the edge, in pixels (up to 64).
- **Light Angle** — where the light comes from, in degrees; 0 is the right, 90 the top, 135 the upper left.
- **Highlight** — strength of the lit side; 0 removes it.
- **Shadow** — strength of the dark side; 0 removes it.

## Use it when

- A title, badge or logo on transparent needs weight: a narrow bevel and a
  shadow strength above the highlight.
- A cut-out element should match a lit scene: set the angle to the key
  light's direction.
- Buttons, chips and lower-third plates in a flat graphic that want one
  touch of relief.

## Avoid when

- Photographic footage with full-frame alpha: there is no edge to bevel,
  only the frame border lights up.
- Thin text at any real width: the slope swallows the strokes and the
  letters go lumpy.
- A whole set of graphics: one bevel is a style, five are a nineties
  slideshow. Stroke or Drop Shadow is quieter.
