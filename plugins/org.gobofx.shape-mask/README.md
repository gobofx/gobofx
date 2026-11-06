# Shape Mask

Keep the picture inside a rounded rectangle or an ellipse and make the rest
transparent, with a feathered edge. Invert to cut a hole instead.

- **Shape**, **Center**, **Width / Height** (in frame heights), **Rotation**.
- **Roundness** — rectangle corner radius; **Feather** — edge softness.
- **Invert** — mask out the inside instead.

## Use it when

- Isolating a region on a duplicated layer so a correction lands only
  there.
- A rounded picture-in-picture, with a little **Feather**.
- Cutting a hole in a layer for a reveal, with **Invert** on.

## Avoid when

- Darkening the edges of the picture. Vignette keeps the picture; this
  removes it.
- Four free corners or a skewed window. Use Corner Mask.
- Keying by colour or brightness. Use Chroma Keyer or Luma Keyer. For bars at
  an aspect ratio, use Widescreen.
