# Comic

The ink-and-colour comic look in one effect: colour flattened to a few
printed levels with a touch more saturation, and dark ink lines drawn where
the picture has edges. **Amount** 0 is the untouched source.

- **Levels** — flat colour steps per channel; 4–6 is a classic comic, 10+ keeps skin tones but loses the look.
- **Edge Threshold** — how strong an edge must be to get a line; 0 inks every ripple, 0.3 only the outlines.
- **Ink** — the line colour; black is the convention, a dark brown or navy is softer.
- **Amount** — 0 is the source, 1 the full look.

## Use it when

- A flashback, a dream or an "as told in the strip" cutaway that must read instantly as drawn.
- A music video or a title sequence that wants a graphic-novel voice, held for a whole section rather than one shot.
- A still or a key art frame being turned into a poster; add Halftone after it for the print.

## Avoid when

- Noisy, grainy or heavily compressed footage: the Sobel pass inks every artefact. Blur first or raise **Edge Threshold**.
- Faces in close-up at low **Levels**: skin bands into orange and brown and the lines land on every pore.
- Only the lines or only the flat colour is wanted; Edges and Posterize do each alone with more control.
