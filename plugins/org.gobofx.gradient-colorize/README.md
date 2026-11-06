# Gradient Colorize

Map the picture's brightness onto a three-stop gradient: one colour for
the blacks, one for the whites and a third parked wherever you put it in
between. The original hues are discarded. Amount 0 is neutral.

- **Blacks** — the stop at black; the default is a near-black violet.
- **Midtones** — the stop at the mid position; the default is a hot red.
- **Whites** — the stop at white; the default is a pale yellow.
- **Mid Position** — where the midtone stop sits on the display scale
  (0.05..0.95); low puts the colour in the shadows, high in the highlights.
- **Amount** — 0 original, 1 full gradient.

## Use it when

- A heat-map, thermal or x-ray read of a plate for a science or crime beat.
- A three-colour poster look for titles, bumpers and lyric cards: dark,
  brand colour, light.
- Making a matte or a depth-like pass readable: three stops show where the
  values sit better than grey does.

## Avoid when

- Faces are the subject: three unrelated hues across a face read as a
  rendering error, not a style. Colorize's two stops are gentler.
- Stops close in brightness with wildly different hues: the gradient bands
  and every bit of noise in the plate shows as a colour edge.
- The look should stay editable by someone else: a LUT carries the same
  idea as one file; this is three colours a host must keep in sync.
