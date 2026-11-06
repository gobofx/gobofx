# Threshold

A hard black-and-white cutoff: everything brighter than the level turns
white, everything darker turns black, with an edge you can soften by a few
pixels (a straight ramp that wide, whatever is under it). Amount 0 is neutral.

- **Level** — the brightness of the cut on the display scale, 0..1 (0.5 is
  mid-grey on a waveform).
- **Softness** — width of the edge in pixels; 0 is a hard step.
- **Invert** — swaps black and white.
- **Amount** — 0 original, 1 full cutoff.

## Use it when

- A high-contrast graphic from footage: a silhouette, a stencil, a
  screen-print plate for a title sequence.
- Building a matte: a luma cut with a soft edge, then feed it to a mask or
  a blend on the layer above.
- A strobe or flash beat where one frame of pure black-and-white hits
  harder than any grade.

## Avoid when

- The subject and its background sit near the same brightness: the cut
  wanders over noise and crawls frame to frame; key on colour instead.
- A graceful black-and-white is wanted: this has two tones; Posterize at
  few levels, or Mono on Color Adjustments, keeps the shape of a face.
- Softness above a few pixels on fine detail: the edge turns to grey mush
  and the point of a threshold is gone.
