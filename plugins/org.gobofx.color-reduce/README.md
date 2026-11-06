# Color Reduce

Limit the picture to a small palette: each channel snaps to a few evenly
spaced levels, with an optional ordered dither that turns the bands into
the regular pattern of an old indexed-colour image. Amount 0 is neutral.

- **Levels** — steps per channel, 2..32; the palette is Levels³ colours (4
  gives 64, like an early computer display).
- **Dither** — a 4×4 ordered pattern before the snap; off gives flat bands.
- **Amount** — 0 original, 1 fully reduced.

## Use it when

- A period computer, console or web-era graphic: few levels with Dither on
  is the texture of that medium.
- A screen-print or risograph still from a photo, with Dither off for flat
  inks.
- A deliberate low-fi beat in a music video or a glitch sequence, cut in
  and out hard.

## Avoid when

- The job is tonal steps rather than a palette: Posterize spaces its levels
  in a chosen gamma and can quantise brightness alone.
- Dither on moving footage at high resolution: the pattern crawls and
  encoders spend their bits on it; pair it with Pixellate at a matching
  block size.
- Faces at low Levels: skin becomes three oranges and a brown.
