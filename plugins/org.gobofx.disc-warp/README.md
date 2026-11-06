# Disc Warp

Wrap the whole frame into a disc: the picture's edges become the rim, the
corners are pulled furthest, and the frame outside the disc is transparent.
Amount blends from the flat frame to the full disc, so at Amount 0 the
picture passes through unchanged.

- **Center** — where the disc sits.
- **Radius** — the disc's radius, in frame heights; 0.5 fills the height.
- **Amount** — 0 is a no-op, 1 the full disc.

## Use it when

- A badge, a porthole or a planet made from a whole shot, composited over
  another layer.
- A record, a dial or a clock face built from a graphic designed flat.
- A keyframed reveal or exit: the frame rolls up into a disc and shrinks
  away, or unrolls from one.

## Avoid when

- A round mask is what you mean: Shape Mask crops, this one squeezes the
  whole frame in.
- Faces: the corners stretch and the middle compresses, and a face
  anywhere but dead centre is pulled into a wedge.
- The rim must stay in frame on a wide shot: a radius over 0.5 clips it top
  and bottom.
