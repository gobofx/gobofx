# Scanlines

Horizontal lines over transparent, pitched in pixels like the raster of a
CRT. Stack it over a clip for a monitor or surveillance feel; roll it slowly
for a failing sync.

- **Spacing** — line pitch in px; 3–6 on 1080p is a tube, 20+ is a venetian
  blind.
- **Thickness** — the dark part of each pitch, 0.05–0.95.
- **Opacity** — 0 hides the lines.
- **Softness** — 0 is a hard raster, 1 a sine-like ripple.
- **Roll** — px per second the lines travel; negative rolls up.
- **Color** — the line colour, usually black; a dark blue reads as a
  monitor, a white at low opacity as a hologram.

## Use it when

- Footage should read as seen on a screen: a security feed, a video call, a
  console in the scene.
- A retro or glitch sequence needs texture that is cheaper and cleaner than
  a full CRT simulation.
- A title wants a hologram or HUD feel: light lines, low opacity, slow roll.

## Avoid when

- Delivering for small screens or heavy compression; lines near the pixel
  pitch alias into moiré after scaling.
- The footage already has a real screen in it; two rasters beat against each
  other.
- The brief is "old film": scanlines are video, use grain and gate weave
  instead.
