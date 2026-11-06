# Starfield

Scattered stars on a near-black sky, each with its own size, brightness and
twinkle phase. The layout is hashed per cell, so the field is the same on
every frame and only the twinkle moves. Set Background alpha to 0 to stack
the stars over a clip.

- **Density** — fraction of the sky that holds a star; 0 is empty.
- **Size** — star radius in px; each star varies down to a third of it.
- **Twinkle** — cycles per second; 0 freezes the stars.
- **Star** — the star colour, with alpha.
- **Background** — the sky; near-black by default, alpha 0 for stars only.

## Use it when

- A night exterior needs a sky it never had: Background alpha 0, stacked
  over the plate with the sky masked or keyed.
- Space, dream and title sequences want depth behind the foreground; two
  layers at different Size and Density give parallax-free depth.
- A slow Twinkle under a lower third keeps a static card alive.

## Avoid when

- The sky is already in shot with real stars or clouds; the hashed grid shows
  as too even next to the real thing.
- Fast camera moves: the stars do not track; a static layer over a pan reads
  as a dirty lens.
- You need a moving field (warp, fly-through); this one holds still.
