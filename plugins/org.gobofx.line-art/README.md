# Line Art

Pen-sketch outlines on paper. Edges in the picture become ink strokes,
everything else is the paper colour with a faint wash where the source is
dark, so a shape with no edges still has a presence. **Amount** 0 returns
the source untouched.

- **Threshold** — contrast needed before a stroke is drawn; 0 inks every ripple, 1 only hard cuts.
- **Line Weight** — in pixels; heavier strokes are wider and softer.
- **Ink** — the pen colour. **Paper** — the sheet; the default is a warm cream.
- **Amount** — 0 is the source, 1 is the sketch; in between is a sketch over the picture.

## Use it when

- An explainer, a storyboard or a "sketched" flashback that must read as drawn, not filmed.
- A title card or a lower third on paper that matches hand-drawn graphics elsewhere in the piece.
- A clean, high-contrast shot of a product, a building or a face in profile; strong outlines make a convincing drawing.

## Avoid when

- Soft, low-contrast or foggy footage: there are no edges to ink and the whole frame goes to paper.
- Noisy or heavily compressed material; grain and block edges turn into scribble. Blur a little first or raise **Threshold**.
- You want lines over the real picture rather than on paper: Edges in its *over Source* mode is the right tool.
