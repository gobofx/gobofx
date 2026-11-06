# Starburst

A burst of radial streaks from a point: inside each streak the picture is
smeared outward along its ray, between the streaks it is left alone, so the
frame reads as a star of motion around the centre. At Amount 0 the picture
passes through unchanged. Pixels pulled from outside the frame repeat the
edge.

- **Center** — where the streaks radiate from.
- **Streaks** — how many, 2 to 32, evenly spaced around the centre.
- **Length** — how far each streak drags, in frame heights.
- **Amount** — mix of the streaks over the picture; 0 is a no-op.

## Use it when

- A hit, a flash or a reveal needs a burst: keyframe Amount up and back
  down over a few frames, centred on the impact.
- A sun, a headlight or a bright title should throw rays; put the centre on
  the light source and keep Length short.
- A comic or a pop-art frame where speed lines radiate from the subject.

## Avoid when

- A smooth zoom blur is wanted: that is every direction at once, this leaves
  gaps between the streaks by design.
- The shot is naturalistic and the subject is a face; rays from a face are a
  halo or a joke, nothing in between.
- The centre is off the frame; the streaks then all run one way and read as
  a directional blur, which another effect does better.
