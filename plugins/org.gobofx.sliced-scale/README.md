# Sliced Scale

Scale the picture the way interface panels are scaled: the four corners keep
their pixel size, the edge bands stretch along one axis only, and only the
middle stretches both ways. The result is centred in the frame and the frame
is transparent around it. At Scale 1, 1 the picture passes through unchanged.

- **Scale X** — width of the result as a fraction of the frame; 1 is a no-op.
- **Scale Y** — height of the result as a fraction of the frame; 1 is a no-op.
- **Corner Size** — the corner square kept unscaled, in pixels; 0 is a plain scale.

## Use it when

- A rounded panel, a speech bubble, a button or a frame graphic has to grow
  or shrink without its corners going oval or its border going thick.
- A lower third or a card animates its width open while the end caps stay
  crisp.
- A screenshot of an interface needs to fit a different aspect and the
  window chrome must not stretch.

## Avoid when

- The picture is a photograph; the seams between the slices show as a
  stretched band through the middle of anything with texture.
- A plain scale is wanted: set Corner Size to 0, or use a transform in the
  host, which also moves and rotates.
- Scaling past the frame; the corners stay in place but the stretched middle
  is cropped, which rarely looks intended.
