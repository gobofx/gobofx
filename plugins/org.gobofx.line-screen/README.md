# Line Screen

The picture as an engraving: parallel ink lines that swell where the
picture is dark and thin where it is light, like a banknote portrait or a
steel etching. **Amount** 0 returns the source untouched.

- **Line Pitch** — in pixels; the distance between line centres. 4–8 px reads as an engraving, 20+ px as a graphic.
- **Angle** — in degrees; the direction of the lines. 45° is the classic, 0° is horizontal.
- **Modulation** — how much the lines swell with darkness; 0 is even lines at half cover, 1 is full tone.
- **Ink** — the line colour. **Paper** — the colour between the lines.
- **Amount** — 0 is the source, 1 is the full screen.

## Use it when

- A heritage, financial or editorial piece wants the look of a printed engraving for a portrait or a landmark.
- A title card or an insert in a monochrome, printed-paper world, with a tinted **Ink** on an off-white **Paper**.
- Turning a map, a diagram or a logo into something that looks etched rather than rendered.

## Avoid when

- Fine detail or small text must survive: anything smaller than the pitch is lost. Use Posterize or Edges instead.
- The frame will be scaled afterwards; a line screen at the wrong size aliases into moiré.
- You want dots rather than lines: Halftone. Lines that bend with the picture: Wavy Screen.
