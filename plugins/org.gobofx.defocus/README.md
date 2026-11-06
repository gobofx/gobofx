# Defocus

A lens blur rather than a Gaussian one: the picture is gathered over a flat
disc or hexagon, so point highlights swell into bokeh shapes instead of
fading into mush. Radius 0 is a no-op.

- **Radius** — bokeh radius in pixels (up to 48).
- **Bokeh Shape** — `disc` for a round iris, `hexagon` for a stopped-down lens.
- **Highlight Boost** — lifts the brights before gathering so the bokeh reads; 0 is a plain flat blur.

## Use it when

- You want a background to read as out of focus, not as softened: lights,
  reflections and specular edges must become discs.
- A title or graphic sits over a shot and needs a believable shallow-focus
  plate behind it.
- A rack-focus or dream moment calls for the lens look, with the highlights
  blooming as the radius animates.

## Avoid when

- You only need to soften noise, banding or a matte edge: Gaussian Blur is
  cleaner and cheaper.
- The frame has no highlights: without brights to shape, this is a noisier
  Gaussian.
- A flat graphic or text needs to stay legible: the flat kernel smears edges
  harder than a Gaussian of the same radius.
