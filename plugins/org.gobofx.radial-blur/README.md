# Radial Blur

A spin blur: every pixel is averaged along an arc around a centre point, so
the frame looks as if it turned during the exposure. The centre stays sharp
and the streaking grows outward. Amount 0 is a no-op.

- **Amount** — the total arc in degrees, spread evenly either side of the frame (up to 90).
- **Center** — the pivot, as an onscreen point.

## Use it when

- A wheel, a turntable, a propeller or a spinning logo needs the motion the
  shutter did not catch.
- A hit, a reveal or a whip needs a quick spin ramp: animate the amount from
  a burst down to 0.
- The eye should be pulled to one point while the edges dissolve into
  circular motion.

## Avoid when

- The motion is a push or a fall, not a turn: Zoom Blur streaks from a point,
  Directional Blur along a line.
- Text or straight edges sit far from the centre: they smear into arcs and
  stop reading.
- You want a soft, still frame: this is a motion look; use Gaussian Blur or
  Defocus.
