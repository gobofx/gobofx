# Edges

Sobel edge detection on perceptual luma. Anything steeper than the threshold
becomes a line in the edge colour; the rest is black, the untouched source,
or transparent, depending on the mode.

- **Threshold** — gradient needed to count as an edge; 0 traces every ripple, 1 only hard cuts.
- **Thickness** — spacing of the Sobel taps in pixels; wider taps give wider, softer lines.
- **Mode** — *Edges on Black* for the classic line drawing, *Edges over Source* to ink the outlines onto the picture, *Edges as Alpha* for lines on transparent that stack over other clips.
- **Edge Color** — the ink.

## Use it when

- A title or insert wants a technical, blueprint or scanner feel: lines on black, or coloured lines as an overlay layer.
- An animation or comic look needs outlines: *Edges over Source* with a dark ink on top of Posterize.
- You need a quick visual of where the detail in a shot actually is, before sharpening or masking it.

## Avoid when

- The footage is noisy or heavily compressed: every block boundary becomes a line. Blur it first or raise the threshold.
- Smooth skin and soft focus are the point of the shot; edges find nothing and the picture goes black.
- You want a painterly outline that follows shapes rather than pixels; this is a per-pixel operator, not a tracer.
