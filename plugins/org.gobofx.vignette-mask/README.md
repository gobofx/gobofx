# Vignette Mask

Keep the picture inside a soft, wide oval and make everything outside it
transparent. The default is a horizontal ellipse nearly as big as the frame
with a wide feather, so what shows through is the centre of the shot.

- **Center** — where the oval sits; drag it onto the subject.
- **Size** — the oval's width as a fraction of the frame width.
- **Aspect** — height over width; below 1 is a wide oval, above 1 a tall one.
- **Feather** — edge softness in frame heights; 0 is a hard cut.
- **Invert** — transparent inside, picture outside: a hole instead of a window.

## Use it when

- A shot should fade into whatever sits beneath it on the timeline: a
  background plate, a colour, a second angle.
- Two clips need to share the frame softly (a face inside a wider shot)
  without a hard split-screen edge.
- You want a darkened-corners look but with your own colour or texture under
  it: mask the clip and put the treatment on the track below.

## Avoid when

- You only want darker corners on an opaque shot: Vignette does that in one
  step without transparency.
- The subject is not centred and not oval: a Shape Mask with rotation or a
  Corner Mask will fit it better.
- The feather is pushed to its maximum to hide a mismatch between the two
  layers; fix the layers instead, the halo reads as a mistake.
