# Stroke

An outline of one colour that follows the alpha shape's edge, drawn
outside it, inside it or straddling it. The edge is found by distance, so
the line is even around corners and curves and stays smooth on a soft
matte. Width 0 is a no-op.

- **Width** — line thickness in pixels (up to 64).
- **Color** — the stroke; a partly transparent colour draws a tinted line.
- **Position** — `outside` grows the shape, `inside` eats into it, `centre` does half of each.

## Use it when

- Titles and captions over busy footage: a dark outside stroke keeps them
  legible without a plate.
- A cut-out subject, a sticker or a keyed element that should pop as a
  pasted-on object.
- Shapes and logos in a graphic package that want one consistent, editable
  outline rather than a baked one.

## Avoid when

- The layer has full-frame alpha: the stroke hugs the frame border, which
  is Simple Border's job.
- Very thin, small text with an inside stroke: the line eats the letters.
- A soft or glowing edge is wanted: Glow or Drop Shadow with no offset, not
  a hard line.
