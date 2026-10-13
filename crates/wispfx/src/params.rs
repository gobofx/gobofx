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
    }
}

fn round_up(n: u32, align: u32) -> u32 {
    n.div_ceil(align) * align
}

/// Compute the uniform layout for the manifest's params, in declaration order.
pub fn layout(manifest: &Manifest) -> Layout {
    let mut fields = Vec::with_capacity(manifest.params.len());
    let mut offset = 0u32;
    for p in &manifest.params {
        let (align, size) = align_size(p.ty);
        offset = round_up(offset, align);
        fields.push(Field { id: p.id.clone(), ty: p.ty, wgsl: p.ty.wgsl(), offset, size });
        offset += size;
    }
    let byte_size = if fields.is_empty() { 0 } else { round_up(offset, 16) };
    Layout { fields, byte_size }
}

/// Signals are one `f32` each, in manifest order (`spec/signals.md`).
pub fn signals_layout(manifest: &Manifest) -> Layout {
    let fields: Vec<Field> = manifest
        .signals
        .iter()
        .enumerate()
        .map(|(i, s)| Field { id: s.id.clone(), ty: ParamType::Float, wgsl: "f32", offset: (i * 4) as u32, size: 4 })
        .collect();
    let byte_size = if fields.is_empty() { 0 } else { round_up(fields.len() as u32 * 4, 16) };
    Layout { fields, byte_size }
}

/// Resolve every signal to a value in 0..1: manifest `default` overridden by `overrides` (id → text).
pub fn resolve_signals(manifest: &Manifest, overrides: &BTreeMap<String, String>) -> Result<Vec<f32>> {
    for id in overrides.keys() {
        if !manifest.signals.iter().any(|s| &s.id == id) {
            bail!("unknown signal '{}' (declared: {:?})", id, manifest.signals.iter().map(|s| s.id.as_str()).collect::<Vec<_>>());
        }
    }
    manifest
        .signals
        .iter()
        .map(|s| {
            let v = match overrides.get(&s.id) {
                Some(text) => text.trim().parse::<f32>().map_err(|e| anyhow!("signal '{}': {}", s.id, e))?,
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
}

/// The manifest `default` for a param, or the type's zero when absent.
pub fn default_value(p: &Param) -> Result<Value> {
    use serde_json::Value as J;
    let d = p.default.as_ref();
    let num = |v: Option<&J>| -> Option<f64> { v.and_then(|v| v.as_f64()) };
    Ok(match p.ty {
        ParamType::Float => Value::Float(num(d).unwrap_or(0.0) as f32),
        ParamType::Int => Value::Int(num(d).unwrap_or(0.0) as i32),
        ParamType::Bool => Value::Bool(d.and_then(|v| v.as_bool()).unwrap_or(false)),
        ParamType::Choice => match d {
            Some(J::Number(n)) => Value::Choice(n.as_f64().unwrap_or(0.0) as u32),
            Some(J::String(s)) => {
                let opts = p.options.as_deref().unwrap_or(&[]);
                let i = opts
                    .iter()
                    .position(|o| o == s)
                    .ok_or_else(|| anyhow!("param '{}': default '{}' is not one of its options", p.id, s))?;
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
    })
}

/// Parse a value from CLI text (`1.5`, `true`, `2`, `option-name`, `r,g,b,a`, `x,y`).
pub fn parse_value(p: &Param, text: &str) -> Result<Value> {
    let text = text.trim();
    let nums = |n: usize| -> Result<Vec<f32>> {
        let v: Vec<f32> = text
            .split(',')
            .map(|s| s.trim().parse::<f32>().map_err(|e| anyhow!("'{}': {}", s.trim(), e)))
            .collect::<Result<_>>()?;
        if v.len() != n {
            bail!("param '{}' expects {} comma-separated numbers, got {}", p.id, n, v.len());
        }
        Ok(v)
    };
    Ok(match p.ty {
        ParamType::Float => Value::Float(text.parse().map_err(|e| anyhow!("param '{}': {}", p.id, e))?),
        ParamType::Int => Value::Int(text.parse().map_err(|e| anyhow!("param '{}': {}", p.id, e))?),
        ParamType::Bool => Value::Bool(matches!(text, "true" | "1" | "yes" | "on")),
        ParamType::Choice => {
            if let Ok(i) = text.parse::<u32>() {
                Value::Choice(i)
            } else {
                let opts = p.options.as_deref().unwrap_or(&[]);
                let i = opts
                    .iter()
                    .position(|o| o == text)
                    .ok_or_else(|| anyhow!("param '{}': '{}' is not one of {:?}", p.id, text, opts))?;
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
    })
}

/// Resolve every param to a value: manifest defaults overridden by `overrides` (id → text).
pub fn resolve(manifest: &Manifest, overrides: &BTreeMap<String, String>) -> Result<Vec<Value>> {
    for id in overrides.keys() {
        if !manifest.params.iter().any(|p| &p.id == id) {
            bail!("unknown param '{}' (declared: {:?})", id, manifest.params.iter().map(|p| p.id.as_str()).collect::<Vec<_>>());
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
    for (field, value) in layout.fields.iter().zip(values) {
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
        }
    }
    buf
}
