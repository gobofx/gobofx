# LUT

Apply a `.cube` 3D lookup table. Pick any LUT the host offers, or one of the
two bundled: **Warm Film** (the default, a gentle print-style grade) and
**Identity** (no change).

- **LUT** — the table. Nothing selected passes the picture through.
- **Intensity** — mix between the original and the graded picture.
- **Input Space** — most LUTs expect display sRGB; pick linear for tables
  built for linear light.

## Use it when

- A camera's technical conversion first: log to display, once, on the track.
- A show look applied to the whole project in one place, so every shot
  shares it.
- Matching a look a client or a colourist handed you as a `.cube`.

## Avoid when

- Footage already in display space when the table expects log, or the other
  way. Check **Input Space**; a doubled curve crushes blacks and skin.
- As a per-shot fixer. A table is not editable; fix exposure in Color
  Adjustments first, then apply the look.
- Two creative LUTs stacked. The second one grades the first one's
  mistakes.
