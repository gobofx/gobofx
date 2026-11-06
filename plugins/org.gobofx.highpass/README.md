# Highpass

Keep only fine detail: the picture minus a blurred copy of itself, re-centred
on mid grey. Everything broader than the radius goes flat grey; edges and
texture stay. **Amount** 0 returns the source untouched.

- **Radius** — in pixels; detail coarser than this is removed. Small values keep only edges, large ones keep local contrast too.
- **Amount** — 0 is the source, 1 is the pure highpass; in between is a flattened picture that keeps its texture.

## Use it when

- Building a detail layer for a frequency split: duplicate the clip, highpass the top copy and blend it over a blurred or graded bottom copy.
- A texture or grain plate needs to be flat grey before it is overlaid on something else.
- Checking where the real detail in a shot is before you sharpen, key or track it.

## Avoid when

- You want a sharper picture: on its own this is a grey plate, not a sharpen. Use Sharpen or Unsharp Mask.
- The shot is noisy or heavily compressed: block edges and grain are the finest detail there is, and they are all that remains.
- A broad, smooth picture (sky, a lit wall) with a small radius goes almost uniformly grey; raise the radius or pick another effect.
