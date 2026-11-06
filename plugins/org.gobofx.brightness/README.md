# Brightness

Add or subtract a constant from the whole picture in linear light, clamped
at black. It is an offset, not a gain: the blacks move with everything
else. The default is neutral, so adding it changes nothing until you move
the control.

- **Amount** — -1..1, added to every channel in linear light; -1 is black,
  0 is neutral, positive lifts the blacks as much as the whites.

## Use it when

- A graphic, a title bed or a solid needs a quick lift or dip without
  changing its contrast.
- A shot is slightly too dark or too bright and you want a one-knob fix
  that an assistant can keyframe.
- Pulling a layer down a little so a caption reads over it.

## Avoid when

- The picture needs its blacks kept: a positive Amount lifts them to grey
  and a negative one crushes them. Exposure on Color Adjustments scales
  instead.
- You are after more punch: this flattens contrast in both directions; use
  Contrast.
- Matching shots: an offset moves the black level, which is the first thing
  a cut reveals.
