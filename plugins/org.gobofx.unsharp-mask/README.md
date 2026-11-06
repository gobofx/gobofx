# Unsharp Mask

The classic sharpen with a threshold: a blurred copy is subtracted from the
picture and the difference added back, but only where the local contrast is
above the threshold. Edges get crisper; flat skin, sky and their noise stay
as they were. Amount 0 is a no-op.

- **Amount** — strength of the added edge contrast; 1 is a normal sharpen, 4 is harsh.
- **Radius** — in pixels; the scale of detail that is enhanced. Small for
  texture, large for a local-contrast look.
- **Threshold** — display-scale local contrast (0..1) below which nothing
  changes; raise it to keep grain and skin out of the sharpening.

## Use it when

- Footage was shot soft or scaled up and needs its edges back without the
  noise coming with them: radius 1..3, threshold around 0.05.
- A large radius (10..30) with a low amount gives a local-contrast lift that
  reads as clarity, not as sharpening.
- Graphics and text rendered through a scale or a blur need their edges
  cleaned up before delivery.

## Avoid when

- The footage is already sharp or heavily compressed: halos and ringing
  show before any detail does.
- Faces fill the frame: pores and stubble sharpen first; raise the
  threshold or mask the sharpen off the skin.
- You need no threshold at all: Sharpen is the same filter with two
  controls and one pass less to think about.
