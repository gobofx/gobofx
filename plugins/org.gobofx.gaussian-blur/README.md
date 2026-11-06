# Gaussian Blur

A true Gaussian blur, separable into a horizontal and a vertical pass.

- **Radius** — in pixels; the kernel covers three sigma.

## Use it when

- Softening a backing layer so a title reads over it.
- Hiding a face or a plate, through a mask on a duplicated layer.
- Filling the pillarbox of a vertical shot with a blurred copy of itself.
- Prepping a layer before Glow or a luma key, so edges do not shimmer.

## Avoid when

- As a transition. Blur Dissolve does the crossfade properly.
- Faking shallow depth of field. A Gaussian has no bokeh; use Defocus.
- A whole-picture "softness" grade. It reads as missed focus. A tiny
  radius under Glow does what you meant.
