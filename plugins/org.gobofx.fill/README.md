# Fill

Paint the inside of a layer's alpha shape with a solid colour or a linear
gradient, keeping the shape and its soft edges exactly. Needs transparency
to work with; on a full-frame clip it is a colour card. **Amount** 0 is the
untouched source.

- **Mode** — *Solid* for one flat colour, *Linear Gradient* for a blend from **Color** to **Second Color**.
- **Color** — the fill, or the gradient's start; its alpha scales the shape's opacity too.
- **Second Color** — the gradient's end.
- **Angle** — the gradient's direction in degrees; 0 runs left to right, 90 top to bottom. It spans the frame, not the shape, so it holds still while the shape moves.
- **Amount** — 0 is the source, 1 the full fill; in between tints the layer.

## Use it when

- Recolouring a keyed subject, a logo or a title to a flat colour or a brand gradient without redoing the asset.
- Turning any cut-out into a silhouette: a dark solid fill with a Drop Shadow behind it.
- Building a graphic from an alpha shape (a stripe, a badge, a mask output), where the fill is the whole design.

## Avoid when

- The layer has no transparency: the result is a flat colour card, which Gradient or a solid generator does with less fuss.
- The gradient must follow the shape's own bounds or a radial falloff; this one is frame-aligned and linear.
- You want to tint rather than replace: a low **Amount** works, but Color Adjustments or Hue/Saturation keep the detail.
