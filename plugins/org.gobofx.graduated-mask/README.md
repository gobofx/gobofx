# Graduated Mask

A straight split with a soft edge, the way a graduated filter sits on a
lens: the picture is kept on one side of a line and fades to transparent on
the other. At the default angle the bottom stays and the top goes.

- **Angle** — in degrees, clockwise; 0 is a horizontal line, 90 a vertical one.
- **Position** — where the line sits, 0..1 across the frame along the split.
- **Feather** — width of the fade in frame heights; 0 is a hard edge.
- **Invert** — keep the other side.

## Use it when

- A sky needs a different grade or a replacement plate: mask the clip,
  put the treatment on the layer below, and the horizon is the line.
- Two shots should meet in a soft diagonal split rather than a hard wipe
  edge held on screen.
- A light source or a reflection should fall off across the frame in one
  direction; stack it with a tinted layer underneath.

## Avoid when

- The horizon is not straight (hills, a skyline): the gradient cuts through
  whatever crosses the line; use a Shape Mask or Corner Mask that follows it.
- You want a moving wipe between two clips: that is a transition, not a
  mask held at one position.
- The feather is so wide the whole frame is a ramp: the picture goes grey
  and flat where it mixes; keep the fade to the band that needs it.
