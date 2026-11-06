# Channel Mixer

Rebuild each output channel from a weighted sum of the three input
channels, in linear light. Nine weights in three rows; the unit matrix is
neutral, so adding it changes nothing until you move a weight.

- **Red from Red / Green / Blue** — the weights that make the red output
  (-2..2; a row that sums to 1 keeps the brightness).
- **Green from Red / Green / Blue** — the green output's row.
- **Blue from Red / Green / Blue** — the blue output's row.
- **Monochrome** — the red row's mix goes to all three channels: a
  black-and-white whose filter you choose.

## Use it when

- A black-and-white conversion with a real filter: red-heavy for dark skies
  and glowing skin, green-heavy for a flatter, documentary tone.
- Swapping or crossing channels on purpose: infrared and false-colour
  looks, a red-blue swap on a sci-fi plate.
- Repairing a channel: a noisy or blown blue channel rebuilt mostly from
  green.

## Avoid when

- Correcting a cast: nine weights are the wrong grip for it; Temperature and
  Tint on Color Adjustments, or Levels, do that in one move.
- Rows that sum far from 1: the picture darkens or clips before anything
  looks intentional, and negative weights pull colours below black.
- You want a monochrome with a colour in it: use Tint or Sepia after a
  Monochrome mix here, not negative weights.
