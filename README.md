# GoboFX

Open standard for portable video effects and transitions: a JSON manifest plus WGSL shaders, running identically in native wgpu hosts and in the browser via WebGPU.

**Status: draft 0.1 — unstable, expect breaking changes.** · https://gobofx.org

| Folder | Contents |
| --- | --- |
| [`spec/`](spec/) | Specification, schema, host prelude and reference examples |
| [`plugins/`](plugins/) | The open-source plugin library, one folder per plugin (`org.gobofx.*`) |
| [`CATALOG.md`](CATALOG.md) | Reference catalogue: the effects and transitions a complete plugin library should cover |
| [`crates/gobofx/`](crates/gobofx/) | Reference crate and the `gobofx` CLI: validate and render plugins headlessly |
| [`apps/site/`](apps/site/) | Source for gobofx.org (SvelteKit on a Cloudflare Worker) |

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE))
- MIT license ([LICENSE-MIT](LICENSE-MIT))

at your option. Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in this work, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.

Contributions require a [DCO](https://developercertificate.org/) sign-off (`git commit -s`).
