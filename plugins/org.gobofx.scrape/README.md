# Scrape

Smear the picture from one edge inward, as if a line of pixels had been
dragged across the frame: everything between the edge and the position
stretches towards that edge until it is one streaked line. At Amount 0 the
picture passes through unchanged; nothing is pulled from outside the frame.

- **Edge** — which edge the smear runs to: left, right, top or bottom.
- **Position** — where the smear starts, 0..1 measured in from that edge.
- **Amount** — 0 is a no-op, 1 drags the line all the way to the edge.

## Use it when

- A slide, swipe or snap transition inside one clip: keyframe Position
  across the frame so a subject wipes its own trail behind it.
- A glitch or a broken-signal moment where a frame tears and a band of it
  smears off the screen.
- Extending a flat edge of a shot (a wall, a sky, a studio cyc) to fill a
  wider frame without stretching the subject.

## Avoid when

- A face or a logo sits inside the strip; stretched features read as a
  rendering fault, not a style.
- The picture should bend or warp smoothly across the whole frame: use
  Wave or Bulge, this only drags one band.
- You want a motion-blur streak; this repeats pixels, it does not blur them.
