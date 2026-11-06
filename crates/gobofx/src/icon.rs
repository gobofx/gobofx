//! `icon.svg` → `icon.png` (spec/package.md, plugins/ICONS.md).
//!
//! A plugin's icon is a hand-drawn pictogram on a 24-unit grid, a single
//! stroke in `currentColor`. Hosts show the rendered PNG; the SVG is the
//! source of truth and this is the one renderer, so every host sees the same
//! pixels: a dark rounded square, the glyph scaled to 80 % of it and tinted
//! by the plugin's category (`tint_for`). Rendering is pure Rust (resvg core:
//! no text, no fonts, no raster images), so a CI box renders what a laptop
//! renders.

use anyhow::{anyhow, Context, Result};
use resvg::tiny_skia::{FillRule, Paint, PathBuilder, Pixmap, Rect, Transform};
use resvg::usvg;

/// Icon edge in pixels; `icon.png` is always square.
pub const ICON_PX: u32 = 128;
/// Background of every icon (the browser's tile colour family).
pub const BACKGROUND: [u8; 3] = [0x15, 0x15, 0x1a];
/// Corner radius as a fraction of the edge.
const RADIUS: f32 = 0.19;
/// The glyph's viewBox fills this fraction of the edge, centred.
const GLYPH: f32 = 0.70;

/// The stroke colour for a category (lowercase slug as in CATALOG.md), by
/// kind so a generator's `light` differs from a transition's.
pub fn tint_for(kind: &str, category: Option<&str>) -> [u8; 3] {
    let c = category.unwrap_or("");
    let hex = match (kind, c) {
        ("effect", "masks") => 0x7dd3fc,
        ("effect", "color") => 0xf472b6,
        ("effect", "looks") => 0xfbbf24,
        ("effect", "blur") => 0xa78bfa,
        ("effect", "sharpen") => 0x34d399,
        ("effect", "distort") => 0xfb923c,
        ("effect", "stylize") => 0xe879f9,
        ("effect", "glow") => 0xfde047,
        ("effect", "tiling") => 0x22d3ee,
        ("effect", "border") => 0xc4b5fd,
        ("effect", "time") => 0x86efac,
        ("transition", "dissolve") => 0x93c5fd,
        ("transition", "wipe") => 0x6ee7b7,
        ("transition", "movement") => 0xfca5a5,
        ("transition", "light") => 0xfde68a,
        ("transition", "object") => 0xf9a8d4,
        ("transition", "clone") => 0xa5f3fc,
        ("transition", "stylized") => 0xd8b4fe,
        ("transition", "blur") => 0xa78bfa,
        ("generator", "solid") => 0xe5e7eb,
        ("generator", "gradient") => 0xc084fc,
        ("generator", "noise") => 0x94a3b8,
        ("generator", "pattern") => 0x5eead4,
        ("generator", "shapes") => 0xfdba74,
        ("generator", "light") => 0xfcd34d,
        _ => 0xd4d4d8,
    };
    [(hex >> 16) as u8, (hex >> 8) as u8, hex as u8]
}

/// Render `svg` (a 24×24 viewBox pictogram using `currentColor`) to an
/// `ICON_PX` square RGBA8 image. Returns (width, height, rgba8).
pub fn render(svg: &str, tint: [u8; 3]) -> Result<(u32, u32, Vec<u8>)> {
    // `currentColor` resolves against the nearest `color` attribute; put the
    // tint on the root so a glyph never has to name a colour itself.
    let colour = format!("#{:02x}{:02x}{:02x}", tint[0], tint[1], tint[2]);
    let svg = svg.replacen("<svg", &format!("<svg color=\"{colour}\""), 1);
    let opts = usvg::Options::default();
    let tree = usvg::Tree::from_str(&svg, &opts).map_err(|e| anyhow!("icon.svg: {e}"))?;
    let size = tree.size();
    if size.width() <= 0.0 || size.height() <= 0.0 {
        return Err(anyhow!("icon.svg: empty size"));
    }

    let edge = ICON_PX as f32;
    let mut pixmap = Pixmap::new(ICON_PX, ICON_PX).context("pixmap")?;
    let mut paint = Paint::default();
    paint.set_color_rgba8(BACKGROUND[0], BACKGROUND[1], BACKGROUND[2], 255);
    paint.anti_alias = true;
    let rect = Rect::from_xywh(0.0, 0.0, edge, edge).context("rect")?;
    let path = rounded_rect(rect, edge * RADIUS);
    pixmap.fill_path(
        &path,
        &paint,
        FillRule::Winding,
        Transform::identity(),
        None,
    );

    let glyph_px = edge * GLYPH;
    let scale = glyph_px / size.width().max(size.height());
    let tx = (edge - size.width() * scale) / 2.0;
    let ty = (edge - size.height() * scale) / 2.0;
    let transform = Transform::from_scale(scale, scale).post_translate(tx, ty);
    resvg::render(&tree, transform, &mut pixmap.as_mut());

    // tiny-skia stores premultiplied RGBA; the PNG we ship is straight alpha,
    // and the background is opaque so the difference only touches edge AA.
    let data = pixmap.take();
    let mut out = Vec::with_capacity(data.len());
    for px in data.chunks_exact(4) {
        let a = px[3] as f32 / 255.0;
        if a > 0.0 {
            out.extend_from_slice(&[
                (px[0] as f32 / a).round().min(255.0) as u8,
                (px[1] as f32 / a).round().min(255.0) as u8,
                (px[2] as f32 / a).round().min(255.0) as u8,
                px[3],
            ]);
        } else {
            out.extend_from_slice(&[0, 0, 0, 0]);
        }
    }
    Ok((ICON_PX, ICON_PX, out))
}

fn rounded_rect(r: Rect, radius: f32) -> resvg::tiny_skia::Path {
    let (x, y, w, h) = (r.x(), r.y(), r.width(), r.height());
    let k = 0.5523; // circle-to-bezier
    let mut pb = PathBuilder::new();
    pb.move_to(x + radius, y);
    pb.line_to(x + w - radius, y);
    pb.cubic_to(
        x + w - radius + radius * k,
        y,
        x + w,
        y + radius - radius * k,
        x + w,
        y + radius,
    );
    pb.line_to(x + w, y + h - radius);
    pb.cubic_to(
        x + w,
        y + h - radius + radius * k,
        x + w - radius + radius * k,
        y + h,
        x + w - radius,
        y + h,
    );
    pb.line_to(x + radius, y + h);
    pb.cubic_to(
        x + radius - radius * k,
        y + h,
        x,
        y + h - radius + radius * k,
        x,
        y + h - radius,
    );
    pb.line_to(x, y + radius);
    pb.cubic_to(
        x,
        y + radius - radius * k,
        x + radius - radius * k,
        y,
        x + radius,
        y,
    );
    pb.close();
    pb.finish().expect("rounded rect path")
}

#[cfg(test)]
mod tests {
    use super::*;

    const GLYPH_SVG: &str = r#"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8"/></svg>"#;

    #[test]
    fn renders_a_tinted_glyph_on_the_dark_square() {
        let (w, h, px) = render(GLYPH_SVG, [0xff, 0x00, 0x00]).unwrap();
        assert_eq!((w, h), (ICON_PX, ICON_PX));
        // Centre is inside the circle's hole: background.
        let c = ((h / 2) * w + w / 2) as usize * 4;
        assert_eq!(&px[c..c + 3], &BACKGROUND);
        // Somewhere on the ring the stroke is red-tinted.
        let ring_x = (w as f32 / 2.0 + 8.0 * (ICON_PX as f32 * GLYPH / 24.0)) as usize;
        let r = ((h / 2) as usize * w as usize + ring_x) * 4;
        assert!(
            px[r] > 180 && px[r + 1] < 80,
            "ring pixel {:?}",
            &px[r..r + 4]
        );
        // Corners are transparent (outside the rounded square).
        assert_eq!(px[3], 0);
    }

    #[test]
    fn tints_differ_by_kind_for_the_same_slug() {
        assert_ne!(
            tint_for("transition", Some("light")),
            tint_for("generator", Some("light"))
        );
        assert_eq!(
            tint_for("effect", None),
            tint_for("effect", Some("unknown"))
        );
    }
}
