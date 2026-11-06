# Circle Blur

A Gaussian blur inside a feathered circle, or, with Blur Outside on,
everywhere but the circle. The blur fades to sharp across the rim rather
than stopping at an edge. Blur 0 is a no-op.

- **Center** — where the circle sits; drag the onscreen handle.
- **Radius** — circle radius in frame heights (1 reaches the top and bottom from the centre).
- **Feather** — width of the soft rim, in frame heights; 0 is a hard edge.
- **Blur** — blur radius in pixels, reached fully inside the circle (up to 48).
- **Blur Outside** — on, the circle stays sharp and the rest of the frame blurs.

## Use it when

- Hiding a face, a plate or a logo: a soft circle over it, animated to
  follow.
- Pulling the eye to one subject with Blur Outside on, when a true shallow
  focus was not shot.
- A spot of dream or memory inside an otherwise sharp frame.

## Avoid when

- The blur should grow smoothly with distance from a point: Variable Blur
  ramps, this fills a disc.
- The region is a strip, not a disc: Gradient Blur.
- The disc has to look like lens focus: a Gaussian never makes bokeh, use
  Defocus with a mask.
