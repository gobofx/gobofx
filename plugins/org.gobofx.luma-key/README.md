# Luma Keyer

Key out the picture by brightness: everything darker than the threshold
becomes transparent, with a soft band above it where the key is partial.
Brightness is read on the display scale, so 0.5 is mid grey on a waveform.

- **Threshold** — display-scale luma (0..1) below which pixels are keyed.
- **Softness** — width of the partial band above the threshold; 0 is a hard key.
- **Invert** — key the bright end and keep the dark instead.
- **Show Matte** — view the alpha as a grey image while tuning.

## Use it when

- A title, logo or texture sits on black and you want only the bright part
  over the picture: threshold low, a little softness.
- Smoke, sparks, lens flares or light leaks shot against black need to stack
  over a clip without a chroma screen.
- A shot needs its sky or hot windows punched out so a replacement can go
  behind it: raise the threshold, invert, feather with softness.

## Avoid when

- The subject and the background share brightness: a luma key cannot tell a
  grey coat from a grey wall; use the Chroma Keyer on a coloured screen.
- Footage is noisy or heavily compressed in the shadows: the edge of the key
  will crawl; denoise first or cut a Shape Mask instead.
- Hair and fine detail matter and the background is not black or white: the
  partial band will fringe.
