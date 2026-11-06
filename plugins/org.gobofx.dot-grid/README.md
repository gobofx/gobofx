# Dot Grid

The picture as a grid of equal dots on a background colour, each dot the
colour of the picture under it, like an LED wall or a Lite-Brite seen up
close. The dots never change size; the colour alone carries the image.
**Amount** 0 is the untouched source.

- **Pitch** — spacing between dot centres in pixels; 8–12 px keeps a face readable, 24+ is pure graphic.
- **Dot Size** — dot diameter as a fraction of the pitch; 1 makes the dots touch, 0.5 shows more background than dot.
- **Background** — the colour between the dots; black for a screen, white for a print.
- **Amount** — 0 is the source, 1 the full grid.

## Use it when

- A stadium screen, scoreboard or LED-wall look: black **Background**, **Dot Size** around 0.8, over bright saturated footage.
- A pop-art or Ben-Day treatment on a still or a title card, with a white or coloured background.
- A reveal into or out of a low-resolution display: animate **Pitch** down to 2 px and the picture resolves.

## Avoid when

- The job is to hide something; this keeps the colour of every cell and reads as decoration. Use Pixellate.
- Tone should drive the dots, as in print; that is Halftone, where dot size follows darkness.
- Fine text or thin lines must survive: anything narrower than the pitch is sampled away.
