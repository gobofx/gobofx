# Wavy Screen

A line screen whose lines ripple: parallel ink lines bent by a wave,
swelling where the picture is dark and thinning where it is light. The
wave gives an engraving a woven, watermark-like texture. **Amount** 0
returns the source untouched.

- **Line Pitch** — in pixels; the distance between line centres.
- **Wave Amplitude** — in pixels; how far each line wanders from straight. 0 is a plain line screen.
- **Wave Frequency** — waves per 100 px along the line; low is a lazy swell, high is a tight ripple.
- **Angle** — in degrees; the direction of the lines, 0 is horizontal.
- **Ink** — the line colour. **Paper** — the colour between the lines.
- **Amount** — 0 is the source, 1 is the full screen.

## Use it when

- A banknote, certificate or security-print feel for a title, a seal or a portrait: small pitch, small amplitude, many waves.
- A woven or textile look for a backing layer, with a muted ink on a paper close to it in tone.
- An op-art or psychedelic insert at a large pitch and amplitude, where the lines themselves are the picture.

## Avoid when

- Legibility matters: detail smaller than the pitch is gone, and the wave bends what remains.
- Straight engraving lines are what you want; that is Line Screen, and it is cleaner.
- The frame will be scaled or shown small; wavy lines at the wrong size turn to moiré.
