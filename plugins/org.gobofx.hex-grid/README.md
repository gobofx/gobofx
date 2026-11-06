# Hex Grid

Hexagonal cells drawn as lines over transparent, with an optional fill
inside each cell. Signed-distance based, so lines stay crisp at any size.

- **Cell Size** — flat-to-flat width in frame heights.
- **Line Width** — in px.
- **Line** — line colour, with alpha.
- **Fill** — inside the cells; transparent by default, give it alpha for a
  tinted honeycomb.
- **Center** — a cell is centred here; **Angle** — turns the grid.

## Use it when

- Tech, sci-fi or sports graphics need a structured background that is not
  the square grid everyone has seen.
- A HUD or shield effect wants a honeycomb reveal: animate Line alpha or
  Fill alpha over a clip.
- A pattern must tile on a moving camera plate; a hex field hides its seams
  better than squares.

## Avoid when

- The frame already holds fine texture: thin lines over detail turn to noise
  on compression.
- The brief is organic or period; a honeycomb says laboratory and little
  else.
- Cells smaller than a few pixels: the lines fill in and the grid becomes a
  grey wash, use Grid or Dots.
