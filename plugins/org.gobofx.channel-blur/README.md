# Channel Blur

A Gaussian blur with its own radius for each of red, green, blue and alpha,
so one channel can smear while the others stay sharp. All four at 0 is a
no-op.

- **Red** — blur radius for the red channel, in pixels (up to 64).
- **Green** — the same for green.
- **Blue** — the same for blue.
- **Alpha** — blur radius for the coverage; softens the shape's edge without touching its colour.

## Use it when

- Faking lens colour fringing or a cheap lens: blur one or two channels a
  few pixels and leave the luma-carrying green sharp.
- Chroma noise on a dark shot: a small blur on red and blue hides it, and
  the picture keeps its detail.
- Softening a matte edge on a cut-out without washing out its colour: blur
  the alpha alone.

## Avoid when

- You just want the picture softer: equal radii are a slower Gaussian Blur.
- The colour should split along a direction rather than bloom around the
  edge: that is Prism.
- Fine coloured text or graphics: an uneven blur makes letters bleed into
  halos nobody intended.
