# Outer Glow

A glow outside the alpha shape only: the silhouette is tinted and blurred,
and the source is laid over it, so the fill stays exactly as it was and the
colour shows where the shape is transparent. Intensity 0 is a no-op.

- **Radius** — spread in pixels (1 to 64).
- **Intensity** — strength; it saturates to a solid rim rather than blowing out.
- **Color** — the glow's colour; its alpha scales the whole glow.

## Use it when

- Titles and lower thirds need separation from a busy background without
  touching the type itself.
- A keyed subject should sit on its plate with a rim of the plate's light
  behind it.
- Stickers, badges and UI graphics want the soft coloured edge that reads
  as a layer style.

## Avoid when

- The glow should bleed into the shape as well: Aura lights the rim from
  both sides.
- The source is a full-frame picture with no transparency: there is no
  outside, so nothing appears.
- It is a glow of the picture's own highlights that is wanted: Glow and Bloom
  work from brightness, not from alpha.
