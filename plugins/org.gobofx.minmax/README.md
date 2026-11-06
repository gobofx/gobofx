# MinMax

Erode or dilate: every pixel takes the darkest (**Min**) or brightest
(**Max**) value found within the radius, on the colour, the alpha, or both.
On alpha it shrinks or grows a matte; on colour it spreads shadows or
highlights into blobs. **Radius** 0 returns the source untouched.

- **Mode** — *Min* erodes (shapes shrink, darks spread), *Max* dilates (shapes grow, brights spread).
- **Radius** — in pixels, up to 8; the window is a square of twice this. Stack two copies for more.
- **Channels** — *RGB* moves colour and keeps the shape, *Alpha* moves the shape and carries its colour with it, *Both* does both.

## Use it when

- Choking a key: *Min* on *Alpha* at 1–2 px eats the green fringe around a keyed subject; add a small blur after.
- Growing a matte or a title's silhouette before a border, a glow or a shadow so the halo clears the edge.
- A cheap painterly or "blob" look: *Max* on *RGB* at 4–8 px turns highlights into brushy patches.

## Avoid when

- You want a soft edge: this is hard-edged by design. Follow it with Gaussian Blur or use Shape Mask's feather.
- On the whole picture as a "bold" filter at a large radius; it reads as a broken render.
- Rounding corners; the window is square, so corners stay square and diagonals go stepped.
