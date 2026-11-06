# Levels

Set where black and white sit and bend the midtones between them, then
nudge each channel on its own. The controls read on the display scale, so a
black point of 0.1 means 10 % grey becomes black, as a waveform shows it.
All defaults are neutral.

- **Black Point** — input level that becomes black (0..0.95).
- **White Point** — input level that becomes white (0.05..1).
- **Gamma** — 1 is neutral; above 1 lifts the midtones, below 1 sinks them.
- **Red / Green / Blue Offset** — added to that channel after the remap
  (-1..1); a small negative blue warms the blacks.

## Use it when

- A flat, log-looking or washed-out shot needs its blacks pinned and its
  whites brought up to full scale before any grading.
- A colour cast lives in the shadows or the whole image: a small offset on
  one channel clears it without touching saturation.
- Several cameras need to agree on black level and contrast before a look
  goes on top of all of them.

## Avoid when

- The picture already uses the full range and you want more punch: moving
  the points then clips; use Contrast on Color Adjustments instead.
- The cast only lives in the highlights or only in the midtones: an offset
  moves the whole channel; Color Balance works by tonal range.
- You are reaching for Gamma to make a look: it is a correction tool, and
  past about 0.7 or 1.5 the midtones go muddy or chalky.
