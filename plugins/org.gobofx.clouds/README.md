# Clouds

Fractal noise shaped into cumulus: the noise is warped by itself for curls
and tears, cut by coverage, and drifts sideways. Two colours, sky and cloud;
give the sky alpha 0 for clouds alone over a clip.

- **Scale** — cloud cells across the frame height; lower is a wider sky.
- **Octaves** — detail layers, 1 (blobs) to 6 (fine wisps).
- **Speed** — drift in cells per second; 0 holds still.
- **Coverage** — 0 is clear sky, 1 overcast.
- **Softness** — 0 hard-edged cut-outs, 1 haze.
- **Sky / Cloud** — the two colours, with alpha.

## Use it when

- A sky replacement needs motion the still plate lacks: Sky alpha 0, low
  Speed, over the graded plate.
- A dream, memory or title sequence wants slow soft texture behind the
  foreground; a low Scale and high Softness read as fog.
- You need an animated matte: sky black, cloud white, and the result drives
  a key or a displacement.

## Avoid when

- A real sky is in frame and sharp; matching the sun direction and the
  perspective of the plate is work this plugin does not do.
- Fast speeds: clouds that visibly race read as a time-lapse, which is a
  decision, not a default.
- Storm or volumetric looks with lit edges and shadowed bases; this is a
  flat two-tone field.
