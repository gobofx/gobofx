//! GoboFX reference implementation.
//!
//! - [`manifest`]: `manifest.json` as typed data (strict: unknown fields are errors).
//! - [`params`]: the `Params` uniform layout and value encoding.
//! - [`validate`]: every rule a conforming host must enforce, with naga validation of each pass.
//! - [`assemble`]: prelude + plugin shader, exactly as a host builds a module.
//! - [`render`]: a headless wgpu host that runs a plugin to an image.
//! - [`pack`]: writes a plugin folder as a `.gobofx` package (`spec/package.md`).
//!
//! The spec lives in `spec/` of the repository; this crate follows it and
//! embeds `spec/prelude.wgsl` so hosts and the CLI agree byte for byte.

pub mod assemble;
pub mod manifest;
pub mod pack;
pub mod params;
pub mod render;
pub mod validate;
#[cfg(target_arch = "wasm32")]
pub mod web;

/// The host prelude, verbatim from `spec/prelude.wgsl`.
pub const PRELUDE: &str = include_str!("../../../spec/prelude.wgsl");

/// Spec version this crate implements.
pub const SPEC_VERSION: &str = "0.1";
