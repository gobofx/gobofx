# Light Rays

Crepuscular rays: everything above the threshold is smeared away from a
light point, as if a haze in front of the picture were lit from there. Put
the light on the sun, a window or a lamp and the brights stream from it.
Intensity 0 is a no-op.

- **Light** — where the rays come from, as an onscreen point; it may sit off-frame.
- **Length** — how far the rays reach, as a fraction of the way to the light.
- **Decay** — how fast a ray fades along its length; 1 carries it the whole way.
- **Intensity** — strength of the rays; above 1 they blow out.
- **Threshold** — brightness that casts rays; raise it to keep the rays to the real lights.

## Use it when

- A sun, a window or a doorway sits in frame (or just outside it) and the
  shot wants god rays it never had.
- A silhouette, foliage or a title should break a light source into shafts.
- A reveal or a flash wants rays that animate: keyframe the intensity, or
  move the light across the frame.

## Avoid when

- There is no clear light source: rays from nowhere read as a filter, not
  as light.
- The brights are scattered all over the frame: every one of them streaks and
  the picture turns to smear; raise the threshold or use Bloom instead.
- The scene is overcast or interior-flat: a haze without a source is Bloom's
  job.
