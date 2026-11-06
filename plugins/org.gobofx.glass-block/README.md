# Glass Block

The frame seen through a wall of glass bricks: each block is flat in the
middle and curves at its rim, where it bends the picture back towards its
own centre, so the image repeats a little at every joint and the joints
themselves show as dark lines. At Refraction 0 the picture passes through
unchanged. Pixels pulled from outside the frame repeat the edge.

- **Block Size** — in frame heights; blocks are square on screen.
- **Refraction** — 0 is a no-op, 1 a thick, heavily bent rim.
- **Edge Softness** — how much of each block is curved rim: 0.05 a thin
  bevel, 1 a curve all the way to the middle.

## Use it when

- Someone or something behind a glass-brick wall, a shower screen or a
  bathroom window; put the plugin on the layer that is behind it.
- An abstract backing plate for a title or a lower third, large blocks,
  moderate refraction.
- A modesty or privacy device that reads as architecture rather than as a
  blur.

## Avoid when

- The point is to hide a face reliably: the middle of each block is a clear
  copy, so use Pixellate or Gaussian Blur under a mask.
- Random, organic glass is what you mean: these are regular bricks, and the
  grid shows.
- The blocks are smaller than about 0.05 on a 16:9 frame; the rims shrink
  to a pixel and the effect reads as a grid overlay.
