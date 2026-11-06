# Drop Shadow

A shadow behind a layer with alpha: the layer's silhouette, moved by an
offset, blurred, tinted, and composited under the layer itself. Needs
transparency to work with; on a full-frame clip there is nothing to cast
one. **Opacity** 0 returns the source untouched.

- **Offset X** / **Offset Y** — in pixels; positive is right and down.
- **Blur** — softness of the shadow edge in pixels; 0 is a hard cut-out.
- **Color** — the shadow colour; its alpha scales the opacity too.
- **Opacity** — 0 to 1.

## Use it when

- Titles, lower thirds and keyed subjects need to sit *on* the background rather than float in it: a small offset (6–12 px) with a blur of about the same size.
- A picture-in-picture or a cut-out needs separation from a busy frame; a large, soft, low-opacity shadow does it without a border.
- A flat graphic wants a little depth without a 3D treatment.

## Avoid when

- The layer has no transparency: nothing is cast and the effect is a no-op.
- The look is flat or editorial by design; a shadow under a title reads as a template.
- You want a glow rather than a shadow: a light colour with zero offset is a poor substitute for Glow.
