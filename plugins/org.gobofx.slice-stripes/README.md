# Stripes

Cut the picture into parallel stripes and slide each one along its own
length, so the frame breaks into offset slices like a stack of pulled
drawers. At Offset 0 the picture passes through unchanged. Where a stripe
slides out of the frame it leaves transparency behind.

- **Stripes** — how many, 2 to 64, across the frame.
- **Angle** — the direction the stripes run; 0 is horizontal, ±90 vertical.
- **Offset** — how far each stripe slides, in frame heights; negative reverses it.
- **Alternate** — on, every other stripe slides the opposite way; off, the stripes shear from one side of the frame to the other.

## Use it when

- A glitch or a data-moshing beat: a dozen stripes, a small offset,
  keyframed on and off in a frame or two.
- A graphic reveal where a title or a still assembles from slices that slide
  into place, keyframing Offset to 0.
- A music-video shuffle on a locked shot, with a coarse count and Alternate
  on.

## Avoid when

- The cut has to stay invisible; even a small offset shows on any edge in
  the shot.
- The split should be a few pieces at odd angles: this is one set of
  parallel stripes, not a shatter.
- A clean skew is wanted: turn Alternate off and raise the count, or use a
  transform in the host.
