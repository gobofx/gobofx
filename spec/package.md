# Package format — v0.1 (draft)

A GoboFX plugin is canonically a **folder** (see [`manifest.md`](manifest.md)). For distribution,
the folder is shipped as a **package**: a ZIP archive with the extension `.gobofx`, constrained by
the profile below so that every host, native or browser, reads it the same way.

The two forms round-trip exactly: unzipping a package yields a valid plugin folder, and zipping a
valid plugin folder's contents (not the folder itself) yields a valid package.

## Why ZIP

- Random access: a host reads `manifest.json` first and inflates only the entries it needs.
- Per-entry compression: WGSL and JSON deflate well; already-compressed textures are stored as-is.
- Universal tooling: authors inspect and build packages with any archiver; no GoboFX tool is required.
- Small parser cost: native hosts use any ZIP library; browsers use `DecompressionStream("deflate-raw")`
  plus a central-directory walk, or a small library.

ZIP's known weak points (path tricks, duplicate names, two sources of truth between local headers and
the central directory, Zip64, encryption) are removed by the profile rather than left to each host.

## Profile

A conforming package MUST satisfy all of the following. A host MUST reject a package that violates
any MUST and SHOULD report which rule failed.

### Container

- A single ZIP archive, no multi-volume, no self-extracting stub.
- Compression method per entry is `0` (stored) or `8` (deflate). Nothing else.
- No encryption, no Zip64 structures, no data descriptors on the `manifest.json` entry.
- Entry names are UTF-8 (general purpose bit 11 set). Hosts MUST NOT fall back to legacy code pages.
- Total uncompressed size of all entries MUST NOT exceed 256 MiB; a package SHOULD stay well under
  32 MiB, since browser hosts hold it in memory.
- Hosts MUST read entries via the central directory and MUST reject an archive whose local headers
  disagree with it (name, sizes, CRC-32).

### Entries

- `manifest.json` MUST be the first entry, stored (method `0`), at the archive root. A host can
  therefore sniff a package by reading the first local header without inflating anything.
- Every entry name is a relative path with `/` separators. No leading `/`, no drive letter, no `.`
  or `..` segments, no backslashes, no control characters, no trailing `/` (directory entries are
  not written; hosts ignore them if present).
- Entry names are unique after Unicode NFC normalization and case folding. Two names that collide
  on a case-insensitive filesystem make the package invalid.
- No symlinks, no external file attributes that a host would honour (hosts ignore them).
- Every `shader` path and every `assets[].file` in the manifest MUST resolve to an entry in the
  package. The reverse is not required: extra entries are allowed.

### Allowed content

| Entry | Required | Notes |
| --- | --- | --- |
| `manifest.json` | yes | See [`manifest.md`](manifest.md) |
| `*.wgsl` | yes (≥1) | Shaders referenced by `passes[].shader` |
| `icon.png` / `icon.webp` | no | Square icon, ≤ 256×256 (128×128 recommended), shown by hosts in lists, menus and on timeline items. Added 2026-10-15 |
| `preview.png` / `preview.webp` | no | Thumbnail for the host's browser, ≤ 512×512, any aspect (16:9 recommended) |
| `README.md` | no | Shown by the host as the plugin description |
| `LICENSE` | no | Full license text; `manifest.license` carries the SPDX expression |
| `*.cube` | no | 3D lookup tables referenced by `assets[].file` ([`assets.md`](assets.md)). Added 2026-10-17 |
| other files | no | Reserved for future asset types (textures). Hosts ignore unknown entries. |

A host MUST NOT execute, evaluate or render any entry it does not recognise. In particular a host
never loads a `.wgsl` file that the manifest does not reference.

## Licensing

The license of a plugin is the author's choice. A package may be open source or commercial and
closed; `manifest.license` is any SPDX expression, including `LicenseRef-Proprietary`, or absent.
A host MUST NOT reject or alter a package because of its license, and MUST NOT require the source
of a plugin to be published. The spec, the schema, the prelude and the reference crate are licensed
MIT OR Apache-2.0 precisely so that the prelude, which the host prepends to every plugin shader, can
be combined with a plugin under any terms the author picks.

## Identity and naming

- The plugin's identity is `manifest.id` + `manifest.version`, not the file name.
- Recommended file name: `<id>-<version>.gobofx`, e.g. `org.gobofx.cross-dissolve-0.1.0.gobofx`.
- Media type: `application/vnd.gobofx+zip`. Magic: ZIP local header `50 4B 03 04` followed by an
  entry named `manifest.json`.
- A host MAY use the SHA-256 of the package bytes as a cache key. Two packages with the same
  `id` and `version` but different hashes are a packaging error; the host SHOULD refuse to replace
  an installed plugin with one of equal version and different hash unless the user asks.

## Out of scope for 0.1

- Signatures and publisher verification. A later revision may add a detached signature entry;
  the profile above (central directory authoritative, no descriptors on the manifest, canonical
  names) is chosen so that signing can be added without changing existing packages.
- Dependencies between plugins. A package is self-contained.
- Install location and catalogs. Where a host keeps packages is the host's business.

## Validation checklist for tools

1. First local header: name `manifest.json`, method 0, no data descriptor.
2. Walk the central directory; apply the entry-name rules; check for duplicates after NFC + case fold.
3. Cross-check each local header against its central entry.
4. Inflate `manifest.json`, validate against [`manifest.schema.json`](manifest.schema.json).
5. Resolve every `passes[].shader`; inflate and validate each shader (naga) with the prelude.
6. Resolve every `assets[].file`; parse each per its kind ([`assets.md`](assets.md) "Validation").
7. Sum uncompressed sizes against the limit.
