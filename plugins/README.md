# plugins/ — the GoboFX plugin library

The open-source plugin library that ships with the standard: the Core and
Planned waves of [`CATALOG.md`](../CATALOG.md), one folder per plugin.
`spec/examples/` is different: it is the conformance set, one minimal
plugin per kind, and changes only when the spec changes.

Start from [`_template/`](_template/): one complete, valid plugin per kind.
Folders starting with `_` are never packed or listed.

## Layout

```
plugins/
└── org.gobofx.<name>/        # folder name == manifest.id
    ├── manifest.json
    ├── <name>.wgsl           # one or more shaders, referenced by passes[].shader
    ├── preview.png           # ≤ 512×512, shown by hosts in their browser
    ├── README.md             # shown by hosts as the plugin description
    └── dist/                 # gitignored: <id>-<version>.gobofx, written by `gobofx pack`
```

## Rules

- **Folder name is the plugin id**, reverse-DNS, `org.gobofx.*` for everything
  in this repo. Third-party contributions use their own namespace.
- **One version per plugin**, `manifest.version` (semver). The library is
  tagged as a whole (`plugins-YYYY.MM`); the spec and the library version
  independently, and each manifest states the spec version it targets in
  `gobofx`.
- **Licence is the repo's**, MIT OR Apache-2.0, DCO sign-off on every commit
  (`git commit -s`). A plugin that differs adds its own `LICENSE` and sets
  `manifest.license`.
- **Every plugin validates** with the reference crate before it is merged:
  `cargo run -p gobofx -- validate plugins/<id>`.
- **Kinds**: `effect` (one input, `source`), `transition` (`from` + `to` +
  `progress`), `generator` (no input).
- **Category** is one of the catalogue's groups, as a lowercase slug.

## Hosts

A host that wants the library as its default catalogue consumes the packed
`.gobofx` files from a tagged release; it never copies these sources.
