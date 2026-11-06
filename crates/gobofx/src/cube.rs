//! `.cube` 3D lookup tables (`spec/assets.md`, kind `lut3d`): the parser and
//! the strip layout a host uploads — N tiles of N×N side by side, blue
//! selecting the tile, red the column and green the row inside it.

use anyhow::{bail, Result};
use half::f16;

pub const MIN_SIZE: u32 = 2;
pub const MAX_SIZE: u32 = 65;

/// A parsed lattice: `size³` RGB triplets, red fastest, then green, then blue.
#[derive(Debug, Clone, PartialEq)]
pub struct Lut3d {
    pub size: u32,
    pub title: Option<String>,
    pub data: Vec<[f32; 3]>,
}

impl Lut3d {
    /// Entry `(r, g, b)` of the lattice.
    pub fn at(&self, r: u32, g: u32, b: u32) -> [f32; 3] {
        self.data[(r + self.size * g + self.size * self.size * b) as usize]
    }

    /// The identity table at `size`.
    pub fn identity(size: u32) -> Lut3d {
        let n = size.max(MIN_SIZE);
        let mut data = Vec::with_capacity((n * n * n) as usize);
        let d = (n - 1) as f32;
        for b in 0..n {
            for g in 0..n {
                for r in 0..n {
                    data.push([r as f32 / d, g as f32 / d, b as f32 / d]);
                }
            }
        }
        Lut3d { size: n, title: None, data }
    }

    /// Strip texture size: `(N·N, N)`.
    pub fn strip_size(&self) -> (u32, u32) {
        (self.size * self.size, self.size)
    }

    /// The strip as `rgba16float` bytes, row-major, alpha 1: texel
    /// `(b·N + r, g)` holds entry `(r, g, b)`.
    pub fn strip_rgba16(&self) -> Vec<u8> {
        let n = self.size;
        let (w, h) = self.strip_size();
        let mut out = Vec::with_capacity((w * h * 8) as usize);
        let one = f16::from_f32(1.0).to_bits().to_le_bytes();
        for g in 0..h {
            for x in 0..w {
                let b = x / n;
                let r = x % n;
                let v = self.at(r, g, b);
                for c in v {
                    out.extend_from_slice(&f16::from_f32(c).to_bits().to_le_bytes());
                }
                out.extend_from_slice(&one);
            }
        }
        out
    }

    /// Serialise as `.cube` text (what `identity` round-trips through).
    pub fn to_cube_text(&self) -> String {
        let mut s = String::new();
        if let Some(t) = &self.title {
            s.push_str(&format!("TITLE \"{}\"\n", t.replace('"', "'")));
        }
        s.push_str(&format!("LUT_3D_SIZE {}\n", self.size));
        for v in &self.data {
            s.push_str(&format!("{:.6} {:.6} {:.6}\n", v[0], v[1], v[2]));
        }
        s
    }
}

/// Parse a `.cube` file per `spec/assets.md`: `LUT_3D_SIZE` 2..=65, default
/// domain only, exactly `N³` triplets, comments and blank lines ignored.
pub fn parse_cube(text: &str) -> Result<Lut3d> {
    let mut size: Option<u32> = None;
    let mut title = None;
    let mut data: Vec<[f32; 3]> = Vec::new();
    for (lineno, raw) in text.lines().enumerate() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let mut words = line.split_whitespace();
        let Some(first) = words.next() else { continue };
        match first {
            "TITLE" => {
                title = Some(line[5..].trim().trim_matches('"').to_string());
            }
            "LUT_3D_SIZE" => {
                let n: u32 = words.next().and_then(|w| w.parse().ok()).ok_or_else(|| anyhow::anyhow!("line {}: LUT_3D_SIZE needs an integer", lineno + 1))?;
                if !(MIN_SIZE..=MAX_SIZE).contains(&n) {
                    bail!("line {}: LUT_3D_SIZE {} is outside {}..={}", lineno + 1, n, MIN_SIZE, MAX_SIZE);
                }
                size = Some(n);
                data.reserve((n * n * n) as usize);
            }
            "LUT_1D_SIZE" => bail!("line {}: 1D LUTs are not a lut3d asset", lineno + 1),
            "DOMAIN_MIN" | "DOMAIN_MAX" => {
                let want = if first == "DOMAIN_MIN" { 0.0 } else { 1.0 };
                let vals: Vec<f32> = words.filter_map(|w| w.parse().ok()).collect();
                if vals.len() != 3 || vals.iter().any(|v| (*v - want).abs() > 1e-6) {
                    bail!("line {}: only the default domain (0 0 0 / 1 1 1) is supported", lineno + 1);
                }
            }
            w if w.parse::<f32>().is_ok() => {
                let r: f32 = w.parse().unwrap();
                let g: f32 = words.next().and_then(|w| w.parse().ok()).ok_or_else(|| anyhow::anyhow!("line {}: expected three values", lineno + 1))?;
                let b: f32 = words.next().and_then(|w| w.parse().ok()).ok_or_else(|| anyhow::anyhow!("line {}: expected three values", lineno + 1))?;
                if !(r.is_finite() && g.is_finite() && b.is_finite()) {
                    bail!("line {}: non-finite value", lineno + 1);
                }
                data.push([r, g, b]);
            }
            other => bail!("line {}: unknown keyword \"{}\"", lineno + 1, other),
        }
    }
    let Some(size) = size else { bail!("missing LUT_3D_SIZE") };
    let want = (size * size * size) as usize;
    if data.len() != want {
        bail!("expected {} entries for LUT_3D_SIZE {}, found {}", want, size, data.len());
    }
    Ok(Lut3d { size, title, data })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_and_round_trips_an_identity() {
        let id = Lut3d::identity(3);
        let text = id.to_cube_text();
        let back = parse_cube(&text).unwrap();
        assert_eq!(back.size, 3);
        assert_eq!(back.at(2, 0, 0), [1.0, 0.0, 0.0]);
        assert_eq!(back.at(0, 1, 2), [0.0, 0.5, 1.0]);
        assert_eq!(back, id);
    }

    #[test]
    fn strip_puts_blue_in_tiles() {
        let id = Lut3d::identity(2);
        assert_eq!(id.strip_size(), (4, 2));
        let bytes = id.strip_rgba16();
        assert_eq!(bytes.len(), 4 * 2 * 8);
        let texel = |x: usize, y: usize| -> [f32; 4] {
            let i = (y * 4 + x) * 8;
            let f = |k: usize| f16::from_bits(u16::from_le_bytes([bytes[i + k * 2], bytes[i + k * 2 + 1]])).to_f32();
            [f(0), f(1), f(2), f(3)]
        };
        assert_eq!(texel(0, 0), [0.0, 0.0, 0.0, 1.0]); // r0 g0 b0
        assert_eq!(texel(1, 0), [1.0, 0.0, 0.0, 1.0]); // r1 g0 b0
        assert_eq!(texel(2, 1), [0.0, 1.0, 1.0, 1.0]); // tile 1 (b1), r0 g1
        assert_eq!(texel(3, 1), [1.0, 1.0, 1.0, 1.0]);
    }

    #[test]
    fn rejects_what_the_spec_rejects() {
        assert!(parse_cube("LUT_3D_SIZE 1\n0 0 0\n").is_err());
        assert!(parse_cube("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n").is_err());
        assert!(parse_cube("LUT_3D_SIZE 2\nDOMAIN_MIN 0 0 0.5\n").is_err());
        assert!(parse_cube("LUT_3D_SIZE 2\n0 0 0\n").is_err(), "too few entries");
        assert!(parse_cube("# comment\nTITLE \"x\"\nLUT_3D_SIZE 2\n").is_err(), "no entries");
        let ok = parse_cube("TITLE \"Neutral\"\n# c\nLUT_3D_SIZE 2\nDOMAIN_MIN 0 0 0\nDOMAIN_MAX 1 1 1\n\n0 0 0\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1\n").unwrap();
        assert_eq!(ok.title.as_deref(), Some("Neutral"));
        assert_eq!(ok.data, Lut3d::identity(2).data);
    }
}
