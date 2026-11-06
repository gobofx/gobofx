# Perspective Tile

The picture tiled on a floor that recedes to a horizon: the bottom row
keeps the size of a flat grid, every row above it shrinks towards the
vanishing line, and the tiles narrow at the same rate, as a real plane does.
Above the line the output is transparent. 1×1 with no tilt is a no-op.

- **Columns / Rows** — tiles across the bottom edge, and tiles per frame height at that scale (1 to 12 each).
- **Tilt** — 0 is a flat grid; 1 vanishes at the horizon; in between the vanishing line sits above the frame.
- **Horizon** — where the plane vanishes at full tilt, 0 top to 0.9.

## Use it when

- A dance floor, a runway, a road or an infinite chessboard built from one
  clip; animate Offset or the clip itself and it scrolls into the distance.
- Retro synthwave and arcade grids, with a sky or a sun composited above
  the transparent horizon.
- Establishing a plane for a title to stand on, or a floor of monitors in a
  control-room gag.

## Avoid when

- The tiles must stay legible all the way up: they shrink to nothing near
  the line and fade out there by design.
- The frame should stay full: the sky above the horizon is empty and wants
  something behind it.
- A simple repeat with no depth is wanted: Tile.
