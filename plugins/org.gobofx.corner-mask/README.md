# Corner Mask

Keep the picture inside a four-corner shape and make the rest transparent.
Each corner is its own handle, so the quad can be a keystone, a slanted
panel or a crooked window; the edge can be hard or feathered. Invert to cut
the shape out instead.

- **Top Left / Top Right / Bottom Right / Bottom Left** — the four corners,
  as positions in the frame; drag them onto what you want to keep.
- **Feather** — edge softness in frame heights; 0 is a hard cut.
- **Invert** — transparent inside, picture outside.

## Use it when

- A screen, a window, a poster or a doorway in the shot needs replacing: set
  the corners on its edges, mask the plate, put the new content behind it.
- A split-screen or a picture-in-picture should sit at an angle instead of
  as a flat rectangle.
- A lamp, a boom or a C-stand pokes into a corner of the frame and the
  layer below can cover it: a thin wedge off that corner, lightly feathered.

## Avoid when

- The thing you are isolating is round or has more than four sides: a
  Shape Mask, or several masks stacked, will follow it better.
- The corners need to track a moving object: a mask only holds the shape;
  keyframe it, or key it instead if it sits on a screen.
- You want perspective, not just a shape: the picture inside is not warped
  to the corners, it is only cut by them.
