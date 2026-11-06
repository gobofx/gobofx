# Shake

Hand-held camera shake: the frame jitters and tilts along a smooth noise
curve that runs with time, so the same frame always shakes the same way.
The edges the move uncovers are transparent; scale the clip up a little, or
let what is beneath show through. Amplitude 0 and Rotation 0 pass the picture
through unchanged.

- **Amplitude** — travel in pixels.
- **Frequency** — jolts per second; 2–4 is a walk, 8–12 a run, 20+ an impact.
- **Rotation** — tilt in degrees; keep it under 3 unless it is a crash.
- **Seed** — a different curve with the same settings, for two clips side by side.

## Use it when

- An impact, an explosion or a hit on the beat: a short burst with Amplitude
  keyframed from 40 to 0 over a few frames.
- A locked-off shot that should feel hand-held among hand-held footage, at a
  few pixels and 2–4 Hz.
- Found-footage, surveillance or run-and-gun energy on material that was shot
  too steady.

## Avoid when

- The shot already moves: shake on top of a pan or a dolly reads as a bad
  encode, not a camera.
- Dialogue close-ups; the eyes stop landing and the audience reads nausea,
  not tension.
- The clip has no room to be scaled up and the transparent edges would show
  over black for the whole shot.
