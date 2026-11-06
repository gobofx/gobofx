# Color Balance

Push the shadows, the midtones and the highlights each towards a colour,
with the classic three sliders per range: cyan-red, magenta-green,
yellow-blue. The ranges are weighted by brightness and blend into each
other, so a shadow shift lifts the blacks the way a lift wheel does and a
highlight shift tints the whites. All defaults are neutral.

- **Shadows Cyan-Red / Magenta-Green / Yellow-Blue** — tint the dark end (-1..1).
- **Midtones Cyan-Red / Magenta-Green / Yellow-Blue** — tint mid grey and skin.
- **Highlights Cyan-Red / Magenta-Green / Yellow-Blue** — tint the bright end.

## Use it when

- The shot wants split toning: cool shadows and warm highlights, or the
  reverse, without touching overall saturation.
- Mixed lighting left a cast in one tonal range only: a tungsten warmth in
  the shadows, a green fluorescent tint in the midtones.
- A clip has to match another whose blacks or whites lean a different way;
  move only the range that disagrees.

## Avoid when

- The whole picture is simply too warm or too cool: one Temperature slider
  on Color Adjustments does it in one move and keeps the ranges in step.
- Skin sits in the midtones and you push Midtones Magenta-Green past about
  0.2: faces go green or pink before anything else shows it.
- You need the blacks to stay black: any shadow shift lifts them; use the
  offsets on Levels, which can also pull a channel down.
