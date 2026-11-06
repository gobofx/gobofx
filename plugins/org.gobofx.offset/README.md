# Offset

The picture slides by a fraction of the frame and wraps around: what goes
off the right comes back in on the left, what goes off the bottom returns
at the top, so the frame stays full and a seam marks the wrap. 0,0 is a
no-op.

- **Offset X** — shift to the right as a fraction of the width, -0.5 to 0.5.
- **Offset Y** — shift down as a fraction of the height, -0.5 to 0.5.

## Use it when

- Checking whether a texture or a pattern clip tiles seamlessly: put the
  seam in the middle and look.
- A scrolling background or a looping ticker; animate one offset over a
  full frame and it cycles.
- Re-framing a seamless texture so its feature sits where you want before
  tiling it.

## Avoid when

- The picture should move without wrapping: that is a position or a
  translate, with the uncovered edge left empty.
- Footage with a subject; the wrap seam cuts straight through it and reads
  as a mistake.
- A mirrored or repeated layout is wanted: Tile and Mirror build those.
