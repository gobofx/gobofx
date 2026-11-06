# Gamma

Bend the midtones with a power curve while black and white stay put, for
the whole picture or one channel at a time. The curve works on the display
scale, the way a monitor's gamma control reads. All defaults are neutral.

- **Gamma** — master, 0.2..5; 1 is neutral, above 1 lifts the midtones,
  below 1 sinks them.
- **Red / Green / Blue Gamma** — the same per channel, multiplied with the
  master; a blue gamma below 1 warms the midtones without touching the
  blacks or the whites.

## Use it when

- A shot is too dark or too bright in the middle but its blacks and whites
  are right: gamma moves the midtones alone, where exposure moves
  everything.
- A colour cast lives in the midtones only: one channel's gamma clears it
  without shifting the black level, which a Levels offset would.
- A graphic made for one display gamma lands on another and its greys sit
  wrong.

## Avoid when

- The blacks or whites are the problem: gamma cannot move them; use Levels.
- Reaching for a look: past about 0.7 or 1.5 the midtones go muddy or
  chalky, and skin loses its shape first.
- The picture is already graded through a LUT: a gamma on top undoes the
  LUT's midtone shape; grade before the table, not after.
