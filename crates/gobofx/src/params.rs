//! The `Params` uniform block: layout per WGSL uniform alignment rules, value encoding.

use std::collections::BTreeMap;

use anyhow::{anyhow, bail, Result};
use serde::Serialize;

use crate::manifest::{Manifest, Param, ParamType};

#[derive(Debug, Clone, Serialize)]
pub struct Field {
    pub id: String,
    #[serde(rename = "type")]
    pub ty: ParamType,
    pub wgsl: &'static str,
    pub offset: u32,
    pub size: u32,
}

#[derive(Debug, Clone, Serialize)]
pub struct Layout {
    pub fields: Vec<Field>,
    /// Buffer size, padded to a multiple of 16. Zero when the plugin declares no params.
    pub byte_size: u32,
}

fn align_size(ty: ParamType) -> (u32, u32) {
    match ty {
        ParamType::Float | ParamType::Int | ParamType::Bool | ParamType::Choice => (4, 4),
        ParamType::Point => (8, 8),
        ParamType::Color => (16, 16),
        ParamType::Asset => (0, 0), // never laid out; `layout` skips it
    }
}

fn round_up(n: u32, align: u32) -> u32 {
    n.div_ceil(align) * align
}

/// Compute the uniform layout for the manifest's params, in declaration order.
pub fn layout(manifest: &Manifest) -> Layout {
    let mut fields = Vec::with_capacity(manifest.params.len());
    let mut offset = 0u32;
    for p in manifest.params.iter().filter(|p| p.ty.is_uniform()) {
        let (align, size) = align_size(p.ty);
        offset = round_up(offset, align);
        fields.push(Field {
            id: p.id.clone(),
            ty: p.ty,
            wgsl: p.ty.wgsl(),
            offset,
            size,
        });
        offset += size;
    }
    let byte_size = if fields.is_empty() {
        0
    } else {
        round_up(offset, 16)
    };
    Layout { fields, byte_size }
}

/// Signals are one `f32` each, in manifest order (`spec/signals.md`).
pub fn signals_layout(manifest: &Manifest) -> Layout {
    let fields: Vec<Field> = manifest
        .signals
        .iter()
        .enumerate()
        .map(|(i, s)| Field {
            id: s.id.clone(),
            ty: ParamType::Float,
            wgsl: "f32",
            offset: (i * 4) as u32,
            size: 4,
        })
        .collect();
    let byte_size = if fields.is_empty() {
        0
    } else {
        round_up(fields.len() as u32 * 4, 16)
    };
    Layout { fields, byte_size }
}

/// Resolve every signal to a value in 0..1: manifest `default` overridden by `overrides` (id → text).
pub fn resolve_signals(
    manifest: &Manifest,
    overrides: &BTreeMap<String, String>,
) -> Result<Vec<f32>> {
    for id in overrides.keys() {
        if !manifest.signals.iter().any(|s| &s.id == id) {
            bail!(
                "unknown signal '{}' (declared: {:?})",
                id,
                manifest
                    .signals
                    .iter()
                    .map(|s| s.id.as_str())
                    .collect::<Vec<_>>()
            );
        }
    }
    manifest
        .signals
        .iter()
        .map(|s| {
            let v = match overrides.get(&s.id) {
                Some(text) => text
                    .trim()
                    .parse::<f32>()
                    .map_err(|e| anyhow!("signal '{}': {}", s.id, e))?,
                None => s.default.unwrap_or(0.0) as f32,
            };
            Ok(v.clamp(0.0, 1.0))
        })
        .collect()
}

/// Encode signal values into the uniform buffer bytes for `layout`.
pub fn encode_signals(layout: &Layout, values: &[f32]) -> Vec<u8> {
    let mut buf = vec![0u8; layout.byte_size as usize];
    for (field, v) in layout.fields.iter().zip(values) {
        let o = field.offset as usize;
        buf[o..o + 4].copy_from_slice(&v.to_le_bytes());
    }
    buf
}

/// A concrete param value, already typed.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(tag = "t", content = "v", rename_all = "lowercase")]
pub enum Value {
    Float(f32),
    Int(i32),
    Bool(bool),
    Choice(u32),
    Color([f32; 4]),
    Point([f32; 2]),
    /// The id of a bundled asset (or a host asset) bound for an `asset` param; `None` = nothing bound.
    Asset(Option<String>),
}

/// The manifest `default` for a param, or the type's zero when absent.
pub fn default_value(p: &Param) -> Result<Value> {
    value_from_json(p, p.default.as_ref())
}

/// A param value from JSON (`default` in the manifest, or a host's `{ id: value }` map).
/// `None` or an unusable value yields the type's zero / the manifest default rules.
pub fn value_from_json(p: &Param, d: Option<&serde_json::Value>) -> Result<Value> {
    use serde_json::Value as J;
    let num = |v: Option<&J>| -> Option<f64> { v.and_then(|v| v.as_f64()) };
    Ok(match p.ty {
        ParamType::Float => Value::Float(num(d).unwrap_or(0.0) as f32),
        ParamType::Int => Value::Int(num(d).unwrap_or(0.0) as i32),
        ParamType::Bool => Value::Bool(d.and_then(|v| v.as_bool()).unwrap_or(false)),
        ParamType::Choice => match d {
            Some(J::Number(n)) => Value::Choice(n.as_f64().unwrap_or(0.0) as u32),
            Some(J::String(s)) => {
                let opts = p.options.as_deref().unwrap_or(&[]);
                let i = opts.iter().position(|o| o == s).ok_or_else(|| {
                    anyhow!(
                        "param '{}': default '{}' is not one of its options",
                        p.id,
                        s
                    )
                })?;
                Value::Choice(i as u32)
            }
            _ => Value::Choice(0),
        },
        ParamType::Color => {
            let mut c = [0.0, 0.0, 0.0, 1.0];
            if let Some(J::Array(a)) = d {
                for (i, v) in a.iter().take(4).enumerate() {
                    c[i] = v.as_f64().unwrap_or(0.0) as f32;
                }
            }
            Value::Color(c)
        }
        ParamType::Point => {
            let mut pt = [0.0, 0.0];
            if let Some(J::Array(a)) = d {
                for (i, v) in a.iter().take(2).enumerate() {
                    pt[i] = v.as_f64().unwrap_or(0.0) as f32;
                }
            }
            Value::Point(pt)
        }
        ParamType::Asset => Value::Asset(match d {
            Some(J::String(s)) if !s.is_empty() => Some(s.clone()),
            _ => None,
        }),
    })
}

/// A JSON param value (a `default`, a preset entry, a host map) as the CLI text
/// `parse_value` reads, so presets and sweeps share one path into `resolve`.
pub fn json_to_text(p: &Param, v: &serde_json::Value) -> Result<String> {
    use serde_json::Value as J;
    let bad = || anyhow!("param '{}': value {} does not fit a {:?}", p.id, v, p.ty);
    Ok(match (p.ty, v) {
        (ParamType::Float, J::Number(n)) | (ParamType::Int, J::Number(n)) => n.to_string(),
        (ParamType::Bool, J::Bool(b)) => b.to_string(),
        (ParamType::Choice, J::Number(n)) => n.to_string(),
        (ParamType::Choice, J::String(s)) => s.clone(),
        (ParamType::Color, J::Array(a)) if a.len() == 4 => a
            .iter()
            .map(|x| x.as_f64().map(|f| f.to_string()).ok_or_else(bad))
            .collect::<Result<Vec<_>>>()?
            .join(","),
        (ParamType::Point, J::Array(a)) if a.len() == 2 => a
            .iter()
            .map(|x| x.as_f64().map(|f| f.to_string()).ok_or_else(bad))
            .collect::<Result<Vec<_>>>()?
            .join(","),
        (ParamType::Asset, J::String(s)) => {
            if s.is_empty() {
                "none".to_string()
            } else {
                s.clone()
            }
        }
        _ => return Err(bad()),
    })
}

/// The override map a preset stands for: every entry as CLI text, keyed by param id.
pub fn preset_overrides(manifest: &Manifest, preset_id: &str) -> Result<BTreeMap<String, String>> {
    let preset = manifest
        .presets
        .iter()
        .find(|q| q.id == preset_id)
        .ok_or_else(|| {
            anyhow!(
                "unknown preset '{}' (have: {})",
                preset_id,
                manifest
                    .presets
                    .iter()
                    .map(|q| q.id.as_str())
                    .collect::<Vec<_>>()
                    .join(", ")
            )
        })?;
    let mut out = BTreeMap::new();
    for (id, v) in &preset.params {
        let p = manifest
            .params
            .iter()
            .find(|p| &p.id == id)
            .ok_or_else(|| anyhow!("preset '{}': '{}' is not a param", preset.id, id))?;
        out.insert(id.clone(), json_to_text(p, v)?);
    }
    Ok(out)
}

/// Parse a value from CLI text (`1.5`, `true`, `2`, `option-name`, `r,g,b,a`, `x,y`).
pub fn parse_value(p: &Param, text: &str) -> Result<Value> {
    let text = text.trim();
    let nums = |n: usize| -> Result<Vec<f32>> {
        let v: Vec<f32> = text
            .split(',')
            .map(|s| {
                s.trim()
                    .parse::<f32>()
                    .map_err(|e| anyhow!("'{}': {}", s.trim(), e))
            })
            .collect::<Result<_>>()?;
        if v.len() != n {
            bail!(
                "param '{}' expects {} comma-separated numbers, got {}",
                p.id,
                n,
                v.len()
            );
        }
        Ok(v)
    };
    Ok(match p.ty {
        ParamType::Float => Value::Float(
            text.parse()
                .map_err(|e| anyhow!("param '{}': {}", p.id, e))?,
        ),
        ParamType::Int => Value::Int(
            text.parse()
                .map_err(|e| anyhow!("param '{}': {}", p.id, e))?,
        ),
        ParamType::Bool => Value::Bool(matches!(text, "true" | "1" | "yes" | "on")),
        ParamType::Choice => {
            if let Ok(i) = text.parse::<u32>() {
                Value::Choice(i)
            } else {
                let opts = p.options.as_deref().unwrap_or(&[]);
                let i = opts.iter().position(|o| o == text).ok_or_else(|| {
                    anyhow!("param '{}': '{}' is not one of {:?}", p.id, text, opts)
                })?;
                Value::Choice(i as u32)
            }
        }
        ParamType::Color => {
            let v = nums(4)?;
            Value::Color([v[0], v[1], v[2], v[3]])
        }
        ParamType::Point => {
            let v = nums(2)?;
            Value::Point([v[0], v[1]])
        }
        ParamType::Asset => Value::Asset(if text.is_empty() || text == "none" {
            None
        } else {
            Some(text.to_string())
        }),
    })
}

/// Resolve every param to a value: manifest defaults overridden by `overrides` (id → text).
pub fn resolve(manifest: &Manifest, overrides: &BTreeMap<String, String>) -> Result<Vec<Value>> {
    for id in overrides.keys() {
        if !manifest.params.iter().any(|p| &p.id == id) {
            bail!(
                "unknown param '{}' (declared: {:?})",
                id,
                manifest
                    .params
                    .iter()
                    .map(|p| p.id.as_str())
                    .collect::<Vec<_>>()
            );
        }
    }
    manifest
        .params
        .iter()
        .map(|p| match overrides.get(&p.id) {
            Some(text) => parse_value(p, text),
            None => default_value(p),
        })
        .collect()
}

/// Encode values into the uniform buffer bytes for `layout`.
pub fn encode(layout: &Layout, values: &[Value]) -> Vec<u8> {
    let mut buf = vec![0u8; layout.byte_size as usize];
    // Asset values are images, not bytes: the layout has no field for them.
    for (field, value) in layout
        .fields
        .iter()
        .zip(values.iter().filter(|v| !matches!(v, Value::Asset(_))))
    {
        let o = field.offset as usize;
        match value {
            Value::Float(f) => buf[o..o + 4].copy_from_slice(&f.to_le_bytes()),
            Value::Int(i) => buf[o..o + 4].copy_from_slice(&i.to_le_bytes()),
            Value::Bool(b) => buf[o..o + 4].copy_from_slice(&(*b as u32).to_le_bytes()),
            Value::Choice(c) => buf[o..o + 4].copy_from_slice(&c.to_le_bytes()),
            Value::Color(c) => {
                for (i, f) in c.iter().enumerate() {
                    buf[o + i * 4..o + i * 4 + 4].copy_from_slice(&f.to_le_bytes());
                }
            }
            Value::Point(p) => {
                for (i, f) in p.iter().enumerate() {
                    buf[o + i * 4..o + i * 4 + 4].copy_from_slice(&f.to_le_bytes());
                }
            }
            Value::Asset(_) => {} // filtered out above; an image has no bytes here
        }
    }
    buf
}

#[cfg(test)]
mod preset_tests {
    use super::*;

    fn manifest() -> Manifest {
        serde_json::from_str(r#"{
            "gobofx": "0.1", "id": "org.gobofx.t", "name": "T", "kind": "effect", "version": "1.0.0",
            "params": [
                { "id": "amount", "type": "float", "default": 0.5, "min": 0, "max": 1 },
                { "id": "mode", "type": "choice", "default": 0, "options": ["a", "b"] },
                { "id": "tint", "type": "color", "default": [1, 1, 1, 1] },
                { "id": "on", "type": "bool", "default": false }
            ],
            "presets": [
                { "id": "warm", "name": "Warm", "params": { "amount": 0.8, "mode": "b", "tint": [1, 0.9, 0.8, 1], "on": true } },
                { "id": "bad", "name": "Bad", "params": { "nope": 1 } }
            ],
            "passes": [ { "shader": "s.wgsl", "entry": "fs", "inputs": ["source"], "output": "out" } ]
        }"#).unwrap()
    }

    #[test]
    fn preset_values_become_cli_text_that_resolve_accepts() {
        let m = manifest();
        let o = preset_overrides(&m, "warm").unwrap();
        assert_eq!(o["amount"], "0.8");
        assert_eq!(o["mode"], "b");
        assert_eq!(o["tint"], "1,0.9,0.8,1");
        assert_eq!(o["on"], "true");
        let values = resolve(&m, &o).unwrap();
        assert!(matches!(values[1], Value::Choice(1)));
        assert!(matches!(values[3], Value::Bool(true)));
    }

    #[test]
    fn unknown_preset_or_param_is_an_error() {
        let m = manifest();
        assert!(preset_overrides(&m, "cold").is_err());
        assert!(preset_overrides(&m, "bad")
            .unwrap_err()
            .to_string()
            .contains("not a param"));
    }
}
