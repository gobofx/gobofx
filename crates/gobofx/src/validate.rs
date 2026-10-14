//! Every rule a conforming host enforces before a plugin reaches the GPU.
//!
//! Manifest rules come from `spec/manifest.md`; shader rules from `spec/shader-abi.md`.
//! Each pass is assembled exactly as a host does (prelude + file) and run through naga
//! with WebGPU-core capabilities, so "passes here" means "compiles in both wgpu and the browser".

use std::collections::BTreeSet;

use naga::{AddressSpace, ImageClass, Module, ScalarKind, ShaderStage, TypeInner, VectorSize};
use serde::Serialize;

use crate::assemble::{assemble, plugin_line};
use crate::manifest::{Kind, ParamType, Plugin};
use crate::params::{self, Layout};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Level {
    Error,
    Warning,
}

#[derive(Debug, Clone, Serialize)]
pub struct Diagnostic {
    pub level: Level,
    /// Pass index (0-based) when the diagnostic is about one pass.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pass: Option<usize>,
    /// Shader file, when known.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub file: Option<String>,
    /// Line in the plugin's shader file (1-based), when known.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub line: Option<usize>,
    pub message: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct PassInfo {
    pub index: usize,
    pub shader: String,
    pub entry: String,
    pub inputs: Vec<String>,
    pub output: String,
    /// Whether the assembled module declares the `params` uniform (group 1, binding 0).
    pub uses_params: bool,
    /// Whether the assembled module declares the `gobofx_signals` uniform (group 1, binding 1).
    pub uses_signals: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct Report {
    pub ok: bool,
    pub id: String,
    pub name: String,
    pub version: String,
    pub kind: Kind,
    pub params: Layout,
    pub signals: Layout,
    pub passes: Vec<PassInfo>,
    pub diagnostics: Vec<Diagnostic>,
}

impl Report {
    pub fn errors(&self) -> usize {
        self.diagnostics.iter().filter(|d| d.level == Level::Error).count()
    }
}

/// Prelude bindings a plugin must not redeclare (group, binding, name).
const PRELUDE_BINDINGS: &[(u32, u32, &str)] = &[
    (0, 0, "gobofx_sampler"),
    (0, 1, "gobofx_globals"),
    (0, 2, "gobofx_input0"),
    (0, 3, "gobofx_input1"),
];

fn is_valid_id(s: &str) -> bool {
    // ^[a-z0-9]+(\.[a-z0-9-]+)+$
    let parts: Vec<&str> = s.split('.').collect();
    parts.len() >= 2
        && !parts[0].is_empty()
        && parts[0].chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit())
        && parts[1..]
            .iter()
            .all(|p| !p.is_empty() && p.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-'))
}

fn is_valid_param_id(s: &str) -> bool {
    // ^[a-z_][a-z0-9_]*$
    let mut chars = s.chars();
    matches!(chars.next(), Some(c) if c.is_ascii_lowercase() || c == '_')
        && chars.all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_')
}

fn is_semver(s: &str) -> bool {
    let core = s.split('-').next().unwrap_or("");
    let nums: Vec<&str> = core.split('.').collect();
    nums.len() == 3 && nums.iter().all(|n| !n.is_empty() && n.chars().all(|c| c.is_ascii_digit()))
}

/// naga's reports quote the assembled source with prelude-shifted line numbers; keep the summary line only.
fn first_line(report: &str) -> String {
    report.lines().next().unwrap_or("").trim_start_matches("error: ").trim().to_string()
}

fn uses_binding(module: &Module, group: u32, binding: u32) -> bool {
    module.global_variables.iter().any(|(_, g)| {
        matches!(g.binding, Some(ref b) if b.group == group && b.binding == binding) && g.space == AddressSpace::Uniform
    })
}

/// Does the assembled module declare the plugin `params` uniform at group 1, binding 0?
pub fn module_uses_params(module: &Module) -> bool {
    uses_binding(module, 1, 0)
}

/// Does the assembled module declare the plugin `gobofx_signals` uniform at group 1, binding 1?
pub fn module_uses_signals(module: &Module) -> bool {
    uses_binding(module, 1, 1)
}

/// Does the module bind anything in group 1 (so the host must attach the group)?
pub fn module_uses_group1(module: &Module) -> bool {
    module_uses_params(module) || module_uses_signals(module)
}

/// Validate a plugin completely. Never panics on bad input; everything is a diagnostic.
pub fn validate(plugin: &Plugin) -> Report {
    let m = &plugin.manifest;
    let mut d: Vec<Diagnostic> = Vec::new();
    let err = |d: &mut Vec<Diagnostic>, pass: Option<usize>, msg: String| {
        d.push(Diagnostic { level: Level::Error, pass, file: None, line: None, message: msg })
    };
    let warn = |d: &mut Vec<Diagnostic>, pass: Option<usize>, msg: String| {
        d.push(Diagnostic { level: Level::Warning, pass, file: None, line: None, message: msg })
    };

    // ── manifest ──────────────────────────────────────────────────────
    if m.gobofx != crate::SPEC_VERSION {
        err(&mut d, None, format!("gobofx must be \"{}\", got \"{}\"", crate::SPEC_VERSION, m.gobofx));
    }
    if !is_valid_id(&m.id) {
        err(&mut d, None, format!("id \"{}\" is not reverse-DNS (^[a-z0-9]+(\\.[a-z0-9-]+)+$)", m.id));
    }
    if m.name.trim().is_empty() {
        err(&mut d, None, "name must not be empty".into());
    }
    if !is_semver(&m.version) {
        err(&mut d, None, format!("version \"{}\" is not semver (MAJOR.MINOR.PATCH)", m.version));
    }

    let mut seen = BTreeSet::new();
    for p in &m.params {
        if !is_valid_param_id(&p.id) {
            err(&mut d, None, format!("param id \"{}\" must match ^[a-z_][a-z0-9_]*$", p.id));
        }
        if !seen.insert(p.id.as_str()) {
            err(&mut d, None, format!("param id \"{}\" is declared twice", p.id));
        }
        if p.ty == ParamType::Choice && p.options.as_ref().is_none_or(|o| o.is_empty()) {
            err(&mut d, None, format!("param \"{}\" is a choice but declares no options", p.id));
        }
        if p.ty != ParamType::Choice && p.options.is_some() {
            warn(&mut d, None, format!("param \"{}\" has options but is not a choice", p.id));
        }
        if let (Some(min), Some(max)) = (p.min, p.max) {
            if min > max {
                err(&mut d, None, format!("param \"{}\": min {} > max {}", p.id, min, max));
            }
        }
        if let Err(e) = params::default_value(p) {
            err(&mut d, None, e.to_string());
        }
    }

    // ── signals (spec/signals.md) ─────────────────────────────────────
    let param_ids: BTreeSet<&str> = m.params.iter().map(|p| p.id.as_str()).collect();
    let mut sig_seen = BTreeSet::new();
    let mut cc_seen = BTreeSet::new();
    let mut note_seen = BTreeSet::new();
    for s in &m.signals {
        if !is_valid_param_id(&s.id) {
            err(&mut d, None, format!("signal id \"{}\" must match ^[a-z_][a-z0-9_]*$", s.id));
        }
        if !sig_seen.insert(s.id.as_str()) {
            err(&mut d, None, format!("signal id \"{}\" is declared twice", s.id));
        }
        if param_ids.contains(s.id.as_str()) {
            err(&mut d, None, format!("signal id \"{}\" collides with a param of the same id", s.id));
        }
        match (s.cc, s.note) {
            (Some(_), Some(_)) => err(&mut d, None, format!("signal \"{}\" binds both cc and note; pick one", s.id)),
            (None, None) => err(&mut d, None, format!("signal \"{}\" must bind a cc or a note", s.id)),
            (Some(cc), None) => {
                if cc > 127 {
                    err(&mut d, None, format!("signal \"{}\": cc {} is out of range 0..127", s.id, cc));
                }
                if !cc_seen.insert((s.channel, cc)) {
                    err(&mut d, None, format!("signal \"{}\": cc {} is already bound on this channel", s.id, cc));
                }
                if s.mode.is_some() {
                    warn(&mut d, None, format!("signal \"{}\": mode only applies to note signals", s.id));
                }
            }
            (None, Some(n)) => {
                if n > 127 {
                    err(&mut d, None, format!("signal \"{}\": note {} is out of range 0..127", s.id, n));
                }
                if !note_seen.insert((s.channel, n)) {
                    err(&mut d, None, format!("signal \"{}\": note {} is already bound on this channel", s.id, n));
                }
            }
        }
        if let Some(ch) = s.channel {
            if !(1..=16).contains(&ch) {
                err(&mut d, None, format!("signal \"{}\": channel {} is out of range 1..16", s.id, ch));
            }
        }
        if let Some(v) = s.default {
            if !(0.0..=1.0).contains(&v) {
                err(&mut d, None, format!("signal \"{}\": default {} is outside 0..1", s.id, v));
            }
        }
        for (name, v) in [("attack_ms", s.attack_ms), ("release_ms", s.release_ms)] {
            if let Some(v) = v {
                if v < 0.0 {
                    err(&mut d, None, format!("signal \"{}\": {} must not be negative", s.id, name));
                }
            }
        }
    }

    // ── pass graph ────────────────────────────────────────────────────
    if m.passes.is_empty() {
        err(&mut d, None, "passes must contain at least one pass".into());
    }
    let reserved = m.kind.reserved_inputs();
    let mut produced: Vec<&str> = Vec::new();
    let last = m.passes.len().saturating_sub(1);
    for (i, pass) in m.passes.iter().enumerate() {
        if pass.inputs.is_empty() || pass.inputs.len() > 2 {
            err(&mut d, Some(i), format!("pass {} must have 1 or 2 inputs, has {}", i, pass.inputs.len()));
        }
        for name in &pass.inputs {
            let ok = reserved.contains(&name.as_str()) || produced.contains(&name.as_str());
            if !ok {
                let reason = if name == "out" {
                    "\"out\" is the final output and cannot be read".to_string()
                } else if matches!(name.as_str(), "source" | "from" | "to") {
                    format!("\"{}\" is reserved for kind {:?}; this plugin is {:?}", name, if name == "source" { Kind::Effect } else { Kind::Transition }, m.kind)
                } else {
                    format!("\"{}\" is neither a reserved input ({}) nor the output of an earlier pass", name, reserved.join(", "))
                };
                err(&mut d, Some(i), format!("pass {} input {}", i, reason));
            }
        }
        if produced.contains(&pass.output.as_str()) || reserved.contains(&pass.output.as_str()) {
            err(&mut d, Some(i), format!("pass {} output \"{}\" is already taken", i, pass.output));
        }
        if i == last && pass.output != "out" {
            err(&mut d, Some(i), format!("the last pass must write \"out\", pass {} writes \"{}\"", i, pass.output));
        }
        if i != last && pass.output == "out" {
            err(&mut d, Some(i), format!("only the last pass may write \"out\" (pass {} of {})", i, m.passes.len()));
        }
        if !pass.shader.ends_with(".wgsl") {
            err(&mut d, Some(i), format!("pass {} shader \"{}\" must be a .wgsl file", i, pass.shader));
        }
        produced.push(pass.output.as_str());
    }

    // ── shaders: assemble + naga, per pass ─────────────────────────────
    let layout = params::layout(m);
    let signals_layout = params::signals_layout(m);
    let mut passes_info = Vec::with_capacity(m.passes.len());
    for (i, pass) in m.passes.iter().enumerate() {
        let mut info = PassInfo {
            index: i,
            shader: pass.shader.clone(),
            entry: pass.entry.clone(),
            inputs: pass.inputs.clone(),
            output: pass.output.clone(),
            uses_params: false,
            uses_signals: false,
        };
        let Some(src) = plugin.shaders.get(&pass.shader) else {
            d.push(Diagnostic {
                level: Level::Error,
                pass: Some(i),
                file: Some(pass.shader.clone()),
                line: None,
                message: format!("shader file \"{}\" not found in {}", pass.shader, plugin.dir.display()),
            });
            passes_info.push(info);
            continue;
        };
        let assembled = assemble(src);
        let module = match naga::front::wgsl::parse_str(&assembled) {
            Ok(mo) => mo,
            Err(e) => {
                let line = e.location(&assembled).and_then(|l| plugin_line(l.line_number as usize));
                d.push(Diagnostic {
                    level: Level::Error,
                    pass: Some(i),
                    file: Some(pass.shader.clone()),
                    line,
                    message: format!("WGSL parse error: {}", first_line(&e.emit_to_string(&assembled))),
                });
                passes_info.push(info);
                continue;
            }
        };
        let mut validator =
            naga::valid::Validator::new(naga::valid::ValidationFlags::all(), naga::valid::Capabilities::empty());
        if let Err(e) = validator.validate(&module) {
            d.push(Diagnostic {
                level: Level::Error,
                pass: Some(i),
                file: Some(pass.shader.clone()),
                line: None,
                message: format!("WGSL validation error: {}", first_line(&e.emit_to_string(&assembled))),
            });
        }
        check_module(&module, plugin, i, &layout, &signals_layout, &mut d);
        info.uses_params = module_uses_params(&module);
        info.uses_signals = module_uses_signals(&module);
        passes_info.push(info);
    }

    let ok = !d.iter().any(|x| x.level == Level::Error);
    Report {
        ok,
        id: m.id.clone(),
        name: m.name.clone(),
        version: m.version.clone(),
        kind: m.kind,
        params: layout,
        signals: signals_layout,
        passes: passes_info,
        diagnostics: d,
    }
}


fn diag(d: &mut Vec<Diagnostic>, level: Level, pass: usize, file: &str, message: String) {
    d.push(Diagnostic { level, pass: Some(pass), file: Some(file.to_string()), line: None, message });
}

fn check_module(module: &Module, plugin: &Plugin, i: usize, layout: &Layout, signals: &Layout, d: &mut Vec<Diagnostic>) {
    let pass = &plugin.manifest.passes[i];

    // Entry points: the manifest entry must be a fragment stage; nothing else but the prelude's vertex.
    match module.entry_points.iter().find(|e| e.name == pass.entry) {
        None => diag(d, Level::Error, i, &pass.shader, format!("entry point \"{}\" not found in {}", pass.entry, pass.shader)),
        Some(e) if e.stage != ShaderStage::Fragment => {
            diag(d, Level::Error, i, &pass.shader, format!("entry point \"{}\" must be @fragment, is {:?}", pass.entry, e.stage))
        }
        Some(_) => {}
    }
    for e in &module.entry_points {
        match e.stage {
            ShaderStage::Compute => diag(d, Level::Error, i, &pass.shader, format!("compute entry point \"{}\" is not allowed in v0.1", e.name)),
            ShaderStage::Vertex if e.name != "gobofx_vs" => {
                diag(d, Level::Error, i, &pass.shader, format!("plugin declares vertex entry point \"{}\"; the host provides gobofx_vs", e.name))
            }
            _ => {}
        }
    }

    // Bindings: only the prelude's group 0 and the plugin's params at group 1 / binding 0.
    let mut params_global = None;
    let mut signals_global = None;
    for (_, g) in module.global_variables.iter() {
        let name = g.name.clone().unwrap_or_default();
        if let AddressSpace::Storage { .. } = g.space {
            diag(d, Level::Error, i, &pass.shader, format!("storage buffer \"{}\" is not allowed in v0.1", name));
        }
        if let TypeInner::Image { class: ImageClass::Storage { .. }, .. } = module.types[g.ty].inner {
            diag(d, Level::Error, i, &pass.shader, format!("storage texture \"{}\" is not allowed in v0.1", name));
        }
        if let TypeInner::Image { arrayed: true, .. } = module.types[g.ty].inner {
            diag(d, Level::Error, i, &pass.shader, format!("texture array \"{}\" is not allowed in v0.1", name));
        }
        let Some(b) = &g.binding else { continue };
        if let Some((_, _, expected)) = PRELUDE_BINDINGS.iter().find(|(gr, bi, _)| *gr == b.group && *bi == b.binding) {
            if name != *expected {
                diag(d, Level::Error, i, &pass.shader, format!("\"{}\" redeclares prelude binding @group({}) @binding({}) ({})", name, b.group, b.binding, expected));
            }
        } else if b.group == 1 && b.binding == 0 {
            if g.space != AddressSpace::Uniform {
                diag(d, Level::Error, i, &pass.shader, format!("\"{}\" at @group(1) @binding(0) must be var<uniform>", name));
            }
            params_global = Some(g);
        } else if b.group == 1 && b.binding == 1 {
            if g.space != AddressSpace::Uniform {
                diag(d, Level::Error, i, &pass.shader, format!("\"{}\" at @group(1) @binding(1) must be var<uniform>", name));
            }
            signals_global = Some(g);
        } else {
            diag(d, Level::Error, i, &pass.shader, format!("\"{}\" declares @group({}) @binding({}); plugins may only declare @group(1) @binding(0) params and @group(1) @binding(1) gobofx_signals", name, b.group, b.binding));
        }
    }

    // Params struct must match the manifest, field for field, in order.
    match params_global {
        None => {
            if !layout.fields.is_empty() {
                d.push(Diagnostic {
                    level: Level::Warning,
                    pass: Some(i),
                    file: Some(pass.shader.clone()),
                    line: None,
                    message: format!("{} declares no params uniform; manifest params are ignored by this pass", pass.shader),
                });
            }
        }
        Some(g) => {
            let TypeInner::Struct { members, .. } = &module.types[g.ty].inner else {
                diag(d, Level::Error, i, &pass.shader, "params must be a struct".into());
                return;
            };
            if layout.fields.is_empty() {
                diag(d, Level::Error, i, &pass.shader, "shader declares a params uniform but the manifest has no params".into());
                return;
            }
            if members.len() != layout.fields.len() {
                diag(d, Level::Error, i, &pass.shader, format!("Params struct has {} fields, manifest declares {}", members.len(), layout.fields.len()));
            }
            for (member, field) in members.iter().zip(&layout.fields) {
                let mname = member.name.clone().unwrap_or_default();
                let inner = &module.types[member.ty].inner;
                let matches = match field.ty {
                    ParamType::Float => matches!(inner, TypeInner::Scalar(s) if s.kind == ScalarKind::Float && s.width == 4),
                    ParamType::Int => matches!(inner, TypeInner::Scalar(s) if s.kind == ScalarKind::Sint && s.width == 4),
                    ParamType::Bool | ParamType::Choice => matches!(inner, TypeInner::Scalar(s) if s.kind == ScalarKind::Uint && s.width == 4),
                    ParamType::Color => matches!(inner, TypeInner::Vector { size: VectorSize::Quad, scalar } if scalar.kind == ScalarKind::Float),
                    ParamType::Point => matches!(inner, TypeInner::Vector { size: VectorSize::Bi, scalar } if scalar.kind == ScalarKind::Float),
                };
                if !matches {
                    diag(d, Level::Error, i, &pass.shader, format!("Params.{} must be {} for manifest param \"{}\" ({:?})", mname, field.wgsl, field.id, field.ty));
                }
                if mname != field.id {
                    d.push(Diagnostic {
                        level: Level::Warning,
                        pass: Some(i),
                        file: Some(pass.shader.clone()),
                        line: None,
                        message: format!("Params.{} is bound by position to manifest param \"{}\"; consider using the same name", mname, field.id),
                    });
                }
                if member.offset != field.offset {
                    diag(d, Level::Error, i, &pass.shader, format!("Params.{} sits at offset {}, host expects {}", mname, member.offset, field.offset));
                }
            }
        }
    }

    // Signals struct must match the manifest: one f32 per signal, in order.
    match signals_global {
        None => {
            if !signals.fields.is_empty() {
                d.push(Diagnostic {
                    level: Level::Warning,
                    pass: Some(i),
                    file: Some(pass.shader.clone()),
                    line: None,
                    message: format!("{} declares no gobofx_signals uniform; manifest signals are ignored by this pass", pass.shader),
                });
            }
        }
        Some(g) => {
            let TypeInner::Struct { members, .. } = &module.types[g.ty].inner else {
                diag(d, Level::Error, i, &pass.shader, "gobofx_signals must be a struct".into());
                return;
            };
            if signals.fields.is_empty() {
                diag(d, Level::Error, i, &pass.shader, "shader declares gobofx_signals but the manifest has no signals".into());
                return;
            }
            if members.len() != signals.fields.len() {
                diag(d, Level::Error, i, &pass.shader, format!("Signals struct has {} fields, manifest declares {} signals", members.len(), signals.fields.len()));
            }
            for (member, field) in members.iter().zip(&signals.fields) {
                let mname = member.name.clone().unwrap_or_default();
                let inner = &module.types[member.ty].inner;
                if !matches!(inner, TypeInner::Scalar(s) if s.kind == ScalarKind::Float && s.width == 4) {
                    diag(d, Level::Error, i, &pass.shader, format!("Signals.{} must be f32 for signal \"{}\"", mname, field.id));
                }
                if mname != field.id {
                    d.push(Diagnostic {
                        level: Level::Warning,
                        pass: Some(i),
                        file: Some(pass.shader.clone()),
                        line: None,
                        message: format!("Signals.{} is bound by position to signal \"{}\"; consider using the same name", mname, field.id),
                    });
                }
                if member.offset != field.offset {
                    diag(d, Level::Error, i, &pass.shader, format!("Signals.{} sits at offset {}, host expects {}", mname, member.offset, field.offset));
                }
            }
        }
    }

    // Override constants: manifest ↔ shader.
    let overrides: Vec<(String, bool)> = module
        .overrides
        .iter()
        .map(|(_, o)| (o.name.clone().unwrap_or_default(), o.init.is_some()))
        .collect();
    for name in pass.constants.keys() {
        if !overrides.iter().any(|(n, _)| n == name) {
            diag(d, Level::Error, i, &pass.shader, format!("constant \"{}\" has no matching `override` in {}", name, pass.shader));
        }
    }
    for (name, has_default) in &overrides {
        if !has_default && !pass.constants.contains_key(name) {
            diag(d, Level::Error, i, &pass.shader, format!("override \"{}\" has no default and pass {} sets no constant for it", name, i));
        }
    }
}
