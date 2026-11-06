# Simple Border

A solid frame along the picture's edge, drawn over the outer pixels or,
with Inset off, around a picture scaled down to fit inside it. Width 0 is a
no-op.

- **Width** — frame thickness in pixels.
- **Color** — the frame; a partly transparent colour tints the edge instead of covering it.
- **Corner Radius** — rounds the frame's inner corners, in pixels.
- **Inset** — on, the frame covers the edge of the picture; off, the picture shrinks so nothing is hidden.

## Use it when

- A picture-in-picture, a split screen or a stacked clip needs a clean edge
  against what is behind it.
- A photo, scan or screen recording should read as an object in the frame:
  a thin white or black border with a small corner radius.
- Several clips in a grid need one consistent, editable frame rather than a
  baked graphic.

## Avoid when

- You want cinema bars: Widescreen masks to an aspect ratio, this draws
  equal sides.
- The edge should be soft, torn or textured: a solid frame reads as a
  web thumbnail, not as a film device.
- The frame would cover a caption or a face: turn Inset off and let the
  picture shrink instead.
