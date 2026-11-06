# Droplet

Rings from a single drop of water, spreading from a point and fading out at
the radius; the rest of the frame is untouched. The troughs are shaded a
little darker so the rings read on flat colour. Nothing moves on its own:
keyframe **Phase** to make the drop spread. At Amplitude 0 the picture passes
through unchanged. Pixels pulled from outside the frame repeat the edge.

- **Center** — where the drop lands.
- **Radius** — how far the rings reach, in frame heights.
- **Rings** — how many rings fit inside the radius.
- **Amplitude** — displacement in frame heights; 0 is a no-op.
- **Decay** — 0 the rings run out to the radius at full strength, 1 only the inner rings survive.
- **Phase** — in ring spacings; +1 moves every ring out by one. Keyframe 0 → 4 for one drop.

## Use it when

- A single, local disturbance: a touch, a drop, a point of impact, something
  landing on the frame.
- A keyframed accent on a beat or a cut — Phase rising, Amplitude falling to 0.
- A lens-on-wet-glass detail on a still or a title, kept small and off-centre.

## Avoid when

- The whole frame should ripple: use Ripple, which has no radius and animates
  by itself.
- Three or more drops: stacking copies looks mechanical, and the rings fight
  where they cross.
- The subject is a face inside the radius; the rings bend features before
  anything else reads as water.
