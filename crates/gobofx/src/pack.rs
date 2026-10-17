//! `.gobofx` package writer — the ZIP profile in `spec/package.md`.
//!
//! Dependency-free on purpose: every entry is STORED (method 0, which the
//! profile allows next to deflate), names are UTF-8 (general purpose bit
//! 11), `manifest.json` is the first entry with no data descriptor, no
//! Zip64, no directory entries, no encryption. A host reads the central
//! directory, so it is written in full and agrees with the local headers.

use std::path::Path;

use anyhow::{bail, Context, Result};

use crate::manifest::Plugin;

/// Entries the profile names besides `manifest.json` and the shaders. Packed
/// when present in the folder, in this order.
pub const OPTIONAL_FILES: &[&str] = &["icon.png", "icon.webp", "preview.png", "preview.webp", "README.md", "LICENSE"];

/// Hard limit from the profile (total uncompressed size).
pub const MAX_TOTAL_BYTES: u64 = 256 * 1024 * 1024;

/// Recommended file name: `<id>-<version>.gobofx`.
pub fn package_file_name(plugin: &Plugin) -> String {
    format!("{}-{}.gobofx", plugin.manifest.id, plugin.manifest.version)
}

/// One file inside the package.
#[derive(Debug, Clone)]
pub struct Entry {
    pub name: String,
    pub bytes: Vec<u8>,
}

/// Entry-name rules from the profile: relative, `/` separators, no `.`/`..`
/// segments, no backslashes, no control characters, no trailing `/`.
pub fn check_entry_name(name: &str) -> Result<()> {
    if name.is_empty() {
        bail!("empty entry name");
    }
    if name.starts_with('/') || name.contains('\\') || name.ends_with('/') {
        bail!("entry name {name:?} must be a relative `/` path without a trailing slash");
    }
    if name.chars().any(|c| c.is_control()) {
        bail!("entry name {name:?} contains a control character");
    }
    if name.split('/').any(|seg| seg.is_empty() || seg == "." || seg == "..") {
        bail!("entry name {name:?} has an empty, `.` or `..` segment");
    }
    if name.len() > u16::MAX as usize {
        bail!("entry name too long");
    }
    Ok(())
}

/// Collect the files of a plugin folder in package order: `manifest.json`,
/// the shaders in pass order (deduplicated), then the optional files.
/// (Reads the filesystem; on wasm targets the reads simply fail.)
pub fn collect_entries(plugin: &Plugin) -> Result<Vec<Entry>> {
    let dir: &Path = &plugin.dir;
    let mut names: Vec<String> = vec!["manifest.json".to_string()];
    for pass in &plugin.manifest.passes {
        if !names.contains(&pass.shader) {
            names.push(pass.shader.clone());
        }
    }
    for a in &plugin.manifest.assets {
        if !names.contains(&a.file) {
            names.push(a.file.clone());
        }
    }
    for f in OPTIONAL_FILES {
        if dir.join(f).is_file() && !names.iter().any(|n| n == f) {
            names.push((*f).to_string());
        }
    }
    let mut entries = Vec::with_capacity(names.len());
    for name in names {
        check_entry_name(&name)?;
        let path = dir.join(&name);
        let bytes = std::fs::read(&path).with_context(|| format!("reading {}", path.display()))?;
        entries.push(Entry { name, bytes });
    }
    check_unique(&entries)?;
    Ok(entries)
}

/// Names must be unique after case folding (the profile also asks for NFC;
/// package names are ASCII in practice and the host rejects collisions).
fn check_unique(entries: &[Entry]) -> Result<()> {
    let mut seen = std::collections::BTreeSet::new();
    for e in entries {
        let folded = e.name.to_lowercase();
        if !seen.insert(folded) {
            bail!("entry name {:?} collides with another entry case-insensitively", e.name);
        }
    }
    Ok(())
}

/// Write the ZIP bytes. `entries[0]` must be `manifest.json`.
pub fn write_zip(entries: &[Entry]) -> Result<Vec<u8>> {
    match entries.first() {
        Some(e) if e.name == "manifest.json" => {}
        _ => bail!("the first entry must be manifest.json"),
    }
    if entries.len() > u16::MAX as usize {
        bail!("too many entries");
    }
    let total: u64 = entries.iter().map(|e| e.bytes.len() as u64).sum();
    if total > MAX_TOTAL_BYTES {
        bail!("package is {total} bytes uncompressed; the limit is {MAX_TOTAL_BYTES}");
    }
    check_unique(entries)?;

    const VERSION_NEEDED: u16 = 20; // 2.0: plain stored/deflate
    const FLAGS_UTF8: u16 = 1 << 11;
    const METHOD_STORED: u16 = 0;
    const DOS_TIME: u16 = 0; // 00:00:00
    const DOS_DATE: u16 = (1 << 5) | 1; // 1980-01-01, deterministic output

    let mut out: Vec<u8> = Vec::new();
    let mut central: Vec<u8> = Vec::new();
    for e in entries {
        check_entry_name(&e.name)?;
        let offset = u32::try_from(out.len()).context("package exceeds 4 GiB")?;
        let size = u32::try_from(e.bytes.len()).context("entry exceeds 4 GiB")?;
        let crc = crc32(&e.bytes);
        let name = e.name.as_bytes();
        let name_len = name.len() as u16;

        // Local file header.
        out.extend_from_slice(&0x0403_4b50u32.to_le_bytes());
        out.extend_from_slice(&VERSION_NEEDED.to_le_bytes());
        out.extend_from_slice(&FLAGS_UTF8.to_le_bytes());
        out.extend_from_slice(&METHOD_STORED.to_le_bytes());
        out.extend_from_slice(&DOS_TIME.to_le_bytes());
        out.extend_from_slice(&DOS_DATE.to_le_bytes());
        out.extend_from_slice(&crc.to_le_bytes());
        out.extend_from_slice(&size.to_le_bytes());
        out.extend_from_slice(&size.to_le_bytes());
        out.extend_from_slice(&name_len.to_le_bytes());
        out.extend_from_slice(&0u16.to_le_bytes()); // extra length
        out.extend_from_slice(name);
        out.extend_from_slice(&e.bytes);

        // Central directory header.
        central.extend_from_slice(&0x0201_4b50u32.to_le_bytes());
        central.extend_from_slice(&VERSION_NEEDED.to_le_bytes()); // version made by
        central.extend_from_slice(&VERSION_NEEDED.to_le_bytes());
        central.extend_from_slice(&FLAGS_UTF8.to_le_bytes());
        central.extend_from_slice(&METHOD_STORED.to_le_bytes());
        central.extend_from_slice(&DOS_TIME.to_le_bytes());
        central.extend_from_slice(&DOS_DATE.to_le_bytes());
        central.extend_from_slice(&crc.to_le_bytes());
        central.extend_from_slice(&size.to_le_bytes());
        central.extend_from_slice(&size.to_le_bytes());
        central.extend_from_slice(&name_len.to_le_bytes());
        central.extend_from_slice(&0u16.to_le_bytes()); // extra length
        central.extend_from_slice(&0u16.to_le_bytes()); // comment length
        central.extend_from_slice(&0u16.to_le_bytes()); // disk number start
        central.extend_from_slice(&0u16.to_le_bytes()); // internal attributes
        central.extend_from_slice(&0u32.to_le_bytes()); // external attributes
        central.extend_from_slice(&offset.to_le_bytes());
        central.extend_from_slice(name);
    }
    let cd_offset = u32::try_from(out.len()).context("package exceeds 4 GiB")?;
    let cd_size = u32::try_from(central.len()).context("central directory too large")?;
    out.extend_from_slice(&central);

    // End of central directory.
    let n = entries.len() as u16;
    out.extend_from_slice(&0x0605_4b50u32.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes()); // this disk
    out.extend_from_slice(&0u16.to_le_bytes()); // disk with the central directory
    out.extend_from_slice(&n.to_le_bytes());
    out.extend_from_slice(&n.to_le_bytes());
    out.extend_from_slice(&cd_size.to_le_bytes());
    out.extend_from_slice(&cd_offset.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes()); // comment length
    Ok(out)
}

/// CRC-32 (IEEE 802.3), the ZIP checksum. Bitwise, no table: packages are
/// small and this keeps the writer dependency-free.
pub fn crc32(data: &[u8]) -> u32 {
    let mut c: u32 = 0xFFFF_FFFF;
    for &b in data {
        c ^= b as u32;
        for _ in 0..8 {
            let mask = (c & 1).wrapping_neg();
            c = (c >> 1) ^ (0xEDB8_8320 & mask);
        }
    }
    !c
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn crc32_matches_known_vectors() {
        assert_eq!(crc32(b""), 0);
        assert_eq!(crc32(b"123456789"), 0xCBF4_3926);
    }

    #[test]
    fn zip_layout_puts_manifest_first_and_agrees_with_central_directory() {
        let entries = vec![
            Entry { name: "manifest.json".into(), bytes: b"{}".to_vec() },
            Entry { name: "shader.wgsl".into(), bytes: b"// wgsl".to_vec() },
        ];
        let z = write_zip(&entries).unwrap();
        // First local header: signature, version 20, flags 0x0800, method 0, name manifest.json.
        assert_eq!(&z[0..4], &0x0403_4b50u32.to_le_bytes());
        assert_eq!(u16::from_le_bytes([z[4], z[5]]), 20);
        assert_eq!(u16::from_le_bytes([z[6], z[7]]), 0x0800);
        assert_eq!(u16::from_le_bytes([z[8], z[9]]), 0);
        assert_eq!(&z[30..43], b"manifest.json");
        // EOCD at the tail: 2 entries, central directory offset points at a central header.
        let eocd = z.len() - 22;
        assert_eq!(&z[eocd..eocd + 4], &0x0605_4b50u32.to_le_bytes());
        assert_eq!(u16::from_le_bytes([z[eocd + 10], z[eocd + 11]]), 2);
        let cd_off = u32::from_le_bytes([z[eocd + 16], z[eocd + 17], z[eocd + 18], z[eocd + 19]]) as usize;
        assert_eq!(&z[cd_off..cd_off + 4], &0x0201_4b50u32.to_le_bytes());
    }

    #[test]
    fn rejects_bad_names_and_wrong_first_entry() {
        assert!(check_entry_name("../x").is_err());
        assert!(check_entry_name("a\\b").is_err());
        assert!(check_entry_name("/abs").is_err());
        assert!(check_entry_name("dir/").is_err());
        assert!(check_entry_name("ok/name.wgsl").is_ok());
        let e = vec![Entry { name: "shader.wgsl".into(), bytes: vec![] }];
        assert!(write_zip(&e).is_err());
    }
}
