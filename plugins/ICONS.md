# Plugin icons — `icon.svg`

Every plugin ships a hand-drawn pictogram, `icon.svg`, next to its
manifest. `gobofx icon <dir>` (and `gobofx verify --assets`) renders it to
the `icon.png` hosts show: a dark rounded square, the glyph scaled to 70 %
of it, stroked in the category's tint. The SVG is the source of truth; the
PNG is derived, so never edit the PNG.

## The grid

- `viewBox="0 0 24 24"`, like Lucide. Draw inside 2..22; the renderer adds
  the padding.
- Strokes only: `fill="none" stroke="currentColor" stroke-width="2"
  stroke-linecap="round" stroke-linejoin="round"` on the root. A filled
  region is allowed when the idea needs it (a solid, a shadow, a sun), as
  `fill="currentColor"` on that element, at most one per icon.
- No text, no raster images, no gradients, no filters, no colours of your
  own. `currentColor` is the only paint; the renderer sets it.
- One idea per icon, three to seven strokes. It has to read at 24 px.

## The language

Start from the picture that is affected, then show the change:

- **A frame** (a 16×11 rounded rectangle) stands for the picture.
  Effects that change the whole picture draw the frame plus the change.
- **Two frames** stand for a transition: `from` on the left or behind,
  `to` on the right or in front, the move between them as an arrow or a
  wipe line.
- **A dot** is a highlight, **wavy lines** are water or distortion,
  **radiating lines** are light, **a grid** is tiling, **a drop**
  is colour, **a circle with a cut** is a mask.
- Transitions in the same family share a construction (all wipes are a
  frame with a dividing line; all movements are two frames and an arrow),
  and differ in the one detail that names them.
- A family that already has a Lucide glyph keeps it recognisable
  (blur ≈ droplets, sharpen ≈ triangle, glow ≈ sun, border ≈ square-in-square).

## Checking

```sh
cargo run -p gobofx -- icon plugins/org.gobofx.<id>
```

then look at `icon.png`, and at a contact sheet of the whole category next
to it: an icon that cannot be told from its neighbour at 24 px needs a
different idea, not more strokes.

## Examples

Cross Dissolve: two overlapping frames, the overlap hatched.

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="2" y="5" width="13" height="10" rx="1.5"/>
  <rect x="9" y="9" width="13" height="10" rx="1.5"/>
  <path d="M11 13l4-4M11 17l6-6"/>
</svg>
```

Gaussian Blur: a frame with three droplets.

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="2" y="4" width="20" height="16" rx="2"/>
  <path d="M8 15.5a2 2 0 1 0 0-.01M12 12a2 2 0 1 0 0-.01M16 15.5a2 2 0 1 0 0-.01"/>
</svg>
```
