//! `manifest.json` — typed, strict. Mirrors `spec/manifest.schema.json`.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Kind {
    Effect,
    Transition,
}

impl Kind {
    /// Reserved input names a plugin of this kind may read.
    pub fn reserved_inputs(self) -> &'static [&'static str] {
        match self {
            Kind::Effect => &["source"],
            Kind::Transition => &["from", "to"],
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ParamType {
    Float,
    Int,
    Bool,
    Choice,
    Color,
    Point,
}

impl ParamType {
    /// WGSL field type the host expects in the plugin's `Params` struct.
    pub fn wgsl(self) -> &'static str {
        match self {
            ParamType::Float => "f32",
            ParamType::Int => "i32",
            ParamType::Bool => "u32",
            ParamType::Choice => "u32",
            ParamType::Color => "vec4f",
            ParamType::Point => "vec2f",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Param {
    pub id: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub label: Option<String>,
    #[serde(rename = "type")]
    pub ty: ParamType,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub default: Option<serde_json::Value>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub min: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub max: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub unit: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub options: Option<Vec<String>>,
    #[serde(default = "default_true")]
    pub animatable: bool,
}

fn default_true() -> bool {
    true
}

/// How a note-bound signal reads the note (`spec/signals.md`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum NoteMode {
    Gate,
    Velocity,
}

/// A signal: a MIDI 2.0 control change or note on the plugin's virtual input,
/// delivered to the shader as one `f32` in 0..1 per frame (`spec/signals.md`).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Signal {
    pub id: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub label: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cc: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub note: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub mode: Option<NoteMode>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub channel: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub hint: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub default: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub attack_ms: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub release_ms: Option<f64>,
}

/// A pipeline-overridable constant value from the manifest (number or boolean).
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum Constant {
    Bool(bool),
    Number(f64),
}

impl Constant {
    pub fn as_f64(self) -> f64 {
        match self {
            Constant::Bool(b) => {
                if b {
                    1.0
                } else {
                    0.0
                }
            }
            Constant::Number(n) => n,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Pass {
    pub shader: String,
    pub entry: String,
    #[serde(default, skip_serializing_if = "BTreeMap::is_empty")]
    pub constants: BTreeMap<String, Constant>,
    pub inputs: Vec<String>,
    pub output: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Manifest {
    pub gobofx: String,
    pub id: String,
    pub name: String,
    pub kind: Kind,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub category: Option<String>,
    pub version: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub license: Option<String>,
    #[serde(default)]
    pub params: Vec<Param>,
    #[serde(default)]
    pub signals: Vec<Signal>,
    pub passes: Vec<Pass>,
}

/// A plugin on disk: its folder, manifest and shader sources (one entry per distinct file).
#[derive(Debug, Clone)]
pub struct Plugin {
    pub dir: PathBuf,
    pub manifest: Manifest,
    /// Shader file name (as written in the manifest) → source text. Missing files are absent here;
    /// `validate` reports them.
    pub shaders: BTreeMap<String, String>,
}

impl Plugin {
    /// Load `manifest.json` and every shader it references from `dir`.
    pub fn load(dir: impl AsRef<Path>) -> Result<Plugin> {
        let dir = dir.as_ref().to_path_buf();
        let manifest_path = dir.join("manifest.json");
        let text = std::fs::read_to_string(&manifest_path)
            .with_context(|| format!("reading {}", manifest_path.display()))?;
        let manifest: Manifest = serde_json::from_str(&text)
            .with_context(|| format!("parsing {}", manifest_path.display()))?;
        let mut shaders = BTreeMap::new();
        for pass in &manifest.passes {
            if shaders.contains_key(&pass.shader) {
                continue;
            }
            if let Ok(src) = std::fs::read_to_string(dir.join(&pass.shader)) {
                shaders.insert(pass.shader.clone(), src);
            }
        }
        Ok(Plugin { dir, manifest, shaders })
    }
}
