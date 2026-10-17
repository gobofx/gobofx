//! `gobofx verify` — render a plugin through a case matrix derived from its
//! manifest, check the results against the contracts the spec and the
//! templates promise, and write a report an agent can read: `report.json`
//! (every case and check), one PNG per case, and `sheet.png`, a labelled
//! contact sheet so the renders can be judged at a glance.
//!
//! The matrix needs no per-plugin test code. An optional `verify.json` in the
//! plugin folder tunes it (see [`Tuning`]); it is never packed.
//!
//! Everything here runs on whatever adapter wgpu finds. On a box with no GPU,
//! `tools/gpu-env.sh` points the Vulkan loader at SwiftShader.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::time::Instant;

use anyhow::{anyhow, Context, Result};
use serde::{Deserialize, Serialize};

use crate::manifest::{Kind, Manifest, Param, ParamType, Plugin};
use crate::params::{self, Value};
use crate::render::{Compiled, Frame, Globals, Host, Image};
use crate::validate;

/// Bundled test images (256×144), so `verify` works from any directory.
pub const FIXTURE_A: &[u8] = include_bytes!("../../../fixtures/a.png");
pub const FIXTURE_B: &[u8] = include_bytes!("../../../fixtures/b.png");
pub const FIXTURE_GREEN: &[u8] = include_bytes!("../../../fixtures/green.png");
pub const FIXTURE_ALPHA: &[u8] = include_bytes!("../../../fixtures/alpha.png");

/// Size every matrix case renders at (the fixtures' size).
pub const CASE_SIZE: (u32, u32) = (256, 144);
/// The timed case.
pub const PERF_SIZE: (u32, u32) = (1280, 720);
/// `preview.png` size written by `--assets`.
pub const PREVIEW_SIZE: (u32, u32) = (512, 288);
pub const ICON_SIZE: u32 = 128;

/// Transitions are swept at this progress: `ease` is inert at exactly 0.5
/// (`mix(p, smoothstep(p), ease)` has a fixed point there), and 0.35 keeps
/// the picture clearly mid-transition.
pub const SWEEP_PROGRESS: f32 = 0.35;
pub const TIME_LATER: f32 = 1.5;

/// Pixel tolerances in 8-bit sRGB: a transition endpoint may differ from its
/// input by the round trip through rgba16float, and a param is "live" when
/// it moves the mean by more than a hair.
pub const ENDPOINT_MAX_DIFF: u8 = 3;
pub const LIVE_MEAN_DIFF: f32 = 0.5;
/// Above this on a hardware adapter the perf check warns.
pub const PERF_WARN_MS: f64 = 250.0;

/// Optional `verify.json` next to `manifest.json`.
#[derive(Debug, Default, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Tuning {
    /// Which fixture feeds `source`: `"a"` (default), `"green"` (subject on
    /// chroma green, for keyers) or `"alpha"` (shapes on transparent, for
    /// masks, borders and glows).
    #[serde(default)]
    pub source: Option<String>,
    /// Params that legitimately don't change the default render (their
    /// liveness check is skipped). Use sparingly; a dead param is usually a bug.
    #[serde(default)]
    pub inert: Vec<String>,
    /// Param overrides under which the output must equal the source
    /// (effects only), e.g. `{ "amount": "0" }`. Values are CLI text.
    #[serde(default)]
    pub identity: BTreeMap<String, String>,
    /// The default render is expected to be a single flat colour (a solid
    /// generator): the "flat output" check then passes instead of warning.
    #[serde(default)]
    pub flat: bool,
}

impl Tuning {
    pub fn load(dir: &Path) -> Result<Tuning> {
        let path = dir.join("verify.json");
        if !path.is_file() {
            return Ok(Tuning::default());
        }
        let text = std::fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
        serde_json::from_str(&text).with_context(|| format!("parsing {}", path.display()))
    }
}

/// One render of the matrix.
#[derive(Debug, Clone, Serialize)]
pub struct Case {
    pub name: String,
    /// Param overrides, CLI text per id (defaults elsewhere).
    pub params: BTreeMap<String, String>,
    pub signals: BTreeMap<String, String>,
    pub progress: f32,
    pub time: f32,
    pub width: u32,
    pub height: u32,
    /// What the case is for; drives which check reads it.
    pub role: Role,
    /// Name of the baseline case this one is compared against for liveness
    /// (`None` = `defaults`). A param that only scales a signal is live only
    /// while that signal is, so sweeps are repeated over the signal baselines.
    pub baseline: Option<String>,
    /// Set after rendering.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ms: Option<f64>,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "snake_case", tag = "kind", content = "of")]
pub enum Role {
    /// Manifest defaults; the baseline every sweep is compared against.
    Baseline,
    /// Baseline rendered again: must be byte-identical.
    Repeat,
    /// Defaults with every signal at one level (1.0 or 0.5): a baseline for signal-scaled params.
    SignalsOn,
    /// Baseline at a later `time`: tells whether the plugin animates.
    Time,
    /// Baseline at a transition progress (the endpoint checks read 0 and 1).
    Progress(f32),
    /// One param moved off its default.
    Param(String),
    /// One signal at 1.0.
    Signal(String),
    /// `verify.json` identity overrides: must equal the source.
    Identity,
    /// Full-size timed render.
    Perf,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Status {
    Pass,
    Warn,
    Fail,
}

#[derive(Debug, Clone, Serialize)]
pub struct Check {
    pub name: String,
    pub status: Status,
    pub detail: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct Summary {
    pub pass: usize,
    pub warn: usize,
    pub fail: usize,
}

#[derive(Debug, Clone, Serialize)]
pub struct Report {
    pub ok: bool,
    pub id: String,
    pub version: String,
    pub kind: Kind,
    pub adapter: String,
    pub backend: String,
    /// SwiftShader / llvmpipe: timings are not representative.
    pub software_gpu: bool,
    pub out_dir: String,
    pub cases: Vec<Case>,
    pub checks: Vec<Check>,
    pub animated: Option<bool>,
    pub summary: Summary,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sheet: Option<String>,
}

pub struct Options {
    /// Where cases, `report.json` and `sheet.png` go (default `<dir>/dist/verify`).
    pub out_dir: Option<PathBuf>,
    /// Also write `preview.png` and `icon.png` into the plugin folder.
    pub assets: bool,
    /// Skip the 1280×720 timed render.
    pub no_perf: bool,
}

// ── Case matrix ──────────────────────────────────────────────────────

fn fmt_f(v: f64) -> String {
    // Shortest text that round-trips through the CLI parser.
    let s = format!("{v}");
    if s.contains('.') || s.contains('e') { s } else { format!("{s}.0") }
}

/// Values of `p` worth trying besides its default, as CLI text. Skips values
/// equal to the default (the render would equal the baseline by construction).
fn sweep_values(p: &Param) -> Vec<(String, String)> {
    let default = params::default_value(p).ok();
    let mut out: Vec<(String, String)> = Vec::new();
    match p.ty {
        ParamType::Float | ParamType::Int => {
            let is_int = p.ty == ParamType::Int;
            let d = match default {
                Some(Value::Float(f)) => f as f64,
                Some(Value::Int(i)) => i as f64,
                _ => 0.0,
            };
            let text = |v: f64| if is_int { format!("{}", v.round() as i64) } else { fmt_f(v) };
            match (p.min, p.max) {
                (Some(lo), Some(hi)) => {
                    if lo != d { out.push(("min".into(), text(lo))); }
                    if hi != d { out.push(("max".into(), text(hi))); }
                }
                (Some(lo), None) => {
                    if lo != d { out.push(("min".into(), text(lo))); }
                    out.push(("x2".into(), text(if d == 0.0 { 1.0 } else { d * 2.0 })));
                }
                (None, Some(hi)) => {
                    if hi != d { out.push(("max".into(), text(hi))); }
                    out.push(("zero".into(), text(0.0)));
                }
                (None, None) => {
                    out.push(("zero".into(), text(0.0)));
                    out.push(("one".into(), text(1.0)));
                }
            }
            out.retain(|(_, t)| Some(t.as_str()) != Some(text(d).as_str()));
        }
        ParamType::Bool => {
            let d = matches!(default, Some(Value::Bool(true)));
            out.push((if d { "off" } else { "on" }.into(), (!d).to_string()));
        }
        ParamType::Choice => {
            let d = match default { Some(Value::Choice(c)) => c, _ => 0 };
            let opts = p.options.as_deref().unwrap_or(&[]);
            for (i, o) in opts.iter().enumerate() {
                if i as u32 != d {
                    out.push((o.clone(), i.to_string()));
                }
            }
        }
        ParamType::Color => {
            let d = match default { Some(Value::Color(c)) => c, _ => [0.0, 0.0, 0.0, 1.0] };
            let cand = if d == [0.0, 1.0, 0.0, 1.0] { ("magenta", "1,0,1,1") } else { ("green", "0,1,0,1") };
            out.push((cand.0.into(), cand.1.into()));
        }
        ParamType::Point => {
            let d = match default { Some(Value::Point(c)) => c, _ => [0.0, 0.0] };
            let cand = if d == [0.15, 0.2] { ("br", "0.85,0.8") } else { ("tl", "0.15,0.2") };
            out.push((cand.0.into(), cand.1.into()));
        }
    }
    out
}

/// The case list for a manifest. Pure, so it can be unit-tested without a GPU.
pub fn cases(m: &Manifest, tuning: &Tuning, perf: bool) -> Vec<Case> {
    let (w, h) = CASE_SIZE;
    let base_progress = if m.kind == Kind::Transition { SWEEP_PROGRESS } else { 0.5 };
    let mk = |name: &str, role: Role| Case {
        name: name.to_string(),
        params: BTreeMap::new(),
        signals: BTreeMap::new(),
        progress: base_progress,
        time: 0.0,
        width: w,
        height: h,
        role,
        baseline: None,
        path: None,
        ms: None,
    };
    let all_at = |level: &str| -> BTreeMap<String, String> { m.signals.iter().map(|s| (s.id.clone(), level.to_string())).collect() };
    // Two signal levels: 1.0 (full) and 0.5 (half). Full alone misses things
    // like a `spin` that is a whole turn at 1.0, or a `key` that only picks the
    // top of a range; half alone misses a `bend` whose rest value is 0.5.
    let levels: [(&str, &str); 2] = [("signals-on", "1"), ("signals-half", "0.5")];
    let signal_default = |s: &crate::manifest::Signal| fmt_f(s.default.unwrap_or(0.0));
    let mut out = vec![mk("defaults", Role::Baseline), mk("repeat", Role::Repeat)];
    if !m.signals.is_empty() {
        for (name, level) in levels {
            let mut c = mk(name, Role::SignalsOn);
            c.signals = all_at(level);
            out.push(c);
        }
    }
    let mut t = mk("time", Role::Time);
    t.time = TIME_LATER;
    out.push(t);
    if m.kind == Kind::Transition {
        for p in [0.0f32, 0.25, 0.5, 0.75, 1.0] {
            let mut c = mk(&format!("progress-{p:.2}"), Role::Progress(p));
            c.progress = p;
            out.push(c);
        }
    }
    for p in &m.params {
        for (tag, text) in sweep_values(p) {
            let mut c = mk(&format!("p-{}-{}", p.id, tag), Role::Param(p.id.clone()));
            c.params.insert(p.id.clone(), text.clone());
            out.push(c);
            if !m.signals.is_empty() {
                for (name, level) in levels {
                    let mut c = mk(&format!("p-{}-{}+{}", p.id, tag, level), Role::Param(p.id.clone()));
                    c.params.insert(p.id.clone(), text.clone());
                    c.signals = all_at(level);
                    c.baseline = Some(name.to_string());
                    out.push(c);
                }
            }
        }
    }
    for s in &m.signals {
        // Alone, at 1.0 and 0.5, against the defaults …
        for (tag, level) in [("", "1"), ("-half", "0.5")] {
            let mut c = mk(&format!("s-{}{}", s.id, tag), Role::Signal(s.id.clone()));
            c.signals.insert(s.id.clone(), level.into());
            out.push(c);
        }
        // … and at its default while every other signal is on (a gate signal
        // like `held` makes the others matter only together).
        if m.signals.len() > 1 {
            for (tag, value) in [("off", signal_default(s)), ("half-on", "0.5".to_string())] {
                let mut c = mk(&format!("s-{}-{}", s.id, tag), Role::Signal(s.id.clone()));
                c.signals = all_at("1");
                c.signals.insert(s.id.clone(), value);
                c.baseline = Some("signals-on".to_string());
                out.push(c);
            }
        }
    }
    if m.kind == Kind::Effect && !tuning.identity.is_empty() {
        let mut c = mk("identity", Role::Identity);
        c.params = tuning.identity.clone();
        out.push(c);
    }
    if perf {
        let mut c = mk("perf", Role::Perf);
        c.width = PERF_SIZE.0;
        c.height = PERF_SIZE.1;
        c.progress = 0.5;
        out.push(c);
    }
    out
}

// ── Running ──────────────────────────────────────────────────────────

fn load_fixture(bytes: &[u8]) -> Image {
    let img = image::load_from_memory(bytes).expect("bundled fixture decodes").to_rgba8();
    Image { width: img.width(), height: img.height(), rgba8: img.into_raw() }
}

/// Inputs for a plugin of this kind, per the tuning.
pub fn inputs_for(kind: Kind, tuning: &Tuning) -> Result<BTreeMap<String, Image>> {
    let mut inputs = BTreeMap::new();
    match kind {
        Kind::Effect => {
            let src = match tuning.source.as_deref().unwrap_or("a") {
                "a" => FIXTURE_A,
                "green" => FIXTURE_GREEN,
                "alpha" => FIXTURE_ALPHA,
                other => return Err(anyhow!("verify.json: source must be a, green or alpha (got {other:?})")),
            };
            inputs.insert("source".into(), load_fixture(src));
        }
        Kind::Transition => {
            inputs.insert("from".into(), load_fixture(FIXTURE_A));
            inputs.insert("to".into(), load_fixture(FIXTURE_B));
        }
        Kind::Generator => {}
    }
    Ok(inputs)
}

fn is_software(adapter: &str) -> bool {
    let a = adapter.to_lowercase();
    a.contains("swiftshader") || a.contains("llvmpipe") || a.contains("lavapipe") || a.contains("warp") || a.contains("software")
}

struct Rendered {
    frame: Frame,
    image: Image,
}

fn render_case(host: &Host, compiled: &Compiled, m: &Manifest, inputs: &BTreeMap<String, Image>, c: &Case) -> Result<(Rendered, f64)> {
    let values = params::resolve(m, &c.params)?;
    let signals = params::resolve_signals(m, &c.signals)?;
    let t0 = Instant::now();
    let frame = host.render_frame(compiled, inputs, (c.width, c.height), Globals { time: c.time, progress: c.progress }, &values, &signals)?;
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    let image = frame.to_image();
    Ok((Rendered { frame, image }, ms))
}

/// Mean absolute difference over all 8-bit channels.
pub fn mean_abs_diff(a: &[u8], b: &[u8]) -> f32 {
    if a.len() != b.len() || a.is_empty() {
        return f32::INFINITY;
    }
    let sum: u64 = a.iter().zip(b).map(|(x, y)| (*x as i32 - *y as i32).unsigned_abs() as u64).sum();
    sum as f32 / a.len() as f32
}

pub fn max_abs_diff(a: &[u8], b: &[u8]) -> u8 {
    if a.len() != b.len() {
        return u8::MAX;
    }
    a.iter().zip(b).map(|(x, y)| (*x as i32 - *y as i32).unsigned_abs() as u8).max().unwrap_or(0)
}

/// Working-space sanity: finite, alpha in range, colour not above alpha
/// (premultiplied) unless the plugin is producing HDR at full alpha.
fn frame_checks(name: &str, f: &Frame, checks: &mut Vec<Check>) {
    let mut nan = 0usize;
    let mut alpha_out = 0usize;
    let mut over = 0usize;
    for px in f.rgba.chunks_exact(4) {
        if px.iter().any(|v| !v.is_finite()) {
            nan += 1;
            continue;
        }
        let a = px[3];
        if !(-1e-3..=1.0 + 1e-3).contains(&a) {
            alpha_out += 1;
        }
        if a < 0.999 && px[..3].iter().any(|c| *c > a + 2e-3) {
            over += 1;
        }
    }
    let total = (f.width * f.height) as usize;
    checks.push(Check {
        name: format!("finite:{name}"),
        status: if nan == 0 { Status::Pass } else { Status::Fail },
        detail: if nan == 0 { "no NaN/Inf".into() } else { format!("{nan}/{total} pixels NaN or Inf") },
    });
    checks.push(Check {
        name: format!("alpha-range:{name}"),
        status: if alpha_out == 0 { Status::Pass } else { Status::Fail },
        detail: if alpha_out == 0 { "alpha within 0..1".into() } else { format!("{alpha_out}/{total} pixels with alpha outside 0..1") },
    });
    checks.push(Check {
        name: format!("premultiplied:{name}"),
        status: if over == 0 { Status::Pass } else { Status::Warn },
        detail: if over == 0 {
            "colour ≤ alpha".into()
        } else {
            format!("{over}/{total} partially transparent pixels with colour above alpha (not premultiplied?)")
        },
    });
}

/// Run the whole matrix for one plugin and write its outputs.
pub fn verify(host: &Host, dir: &Path, opts: &Options) -> Result<Report> {
    let plugin = Plugin::load(dir)?;
    let m = &plugin.manifest;
    let tuning = Tuning::load(dir)?;
    let out_dir = opts.out_dir.clone().unwrap_or_else(|| dir.join("dist").join("verify"));
    std::fs::create_dir_all(&out_dir).with_context(|| format!("creating {}", out_dir.display()))?;

    let mut checks = Vec::new();
    let mut report = Report {
        ok: false,
        id: m.id.clone(),
        version: m.version.clone(),
        kind: m.kind,
        adapter: host.adapter_name.clone(),
        backend: host.backend.clone(),
        software_gpu: is_software(&host.adapter_name),
        out_dir: out_dir.display().to_string(),
        cases: Vec::new(),
        checks: Vec::new(),
        animated: None,
        summary: Summary { pass: 0, warn: 0, fail: 0 },
        sheet: None,
    };

    let v = validate::validate(&plugin);
    let errors: Vec<String> = v
        .diagnostics
        .iter()
        .filter(|d| d.level == validate::Level::Error)
        .map(|d| match (&d.file, d.line) {
            (Some(f), Some(l)) => format!("{f}:{l}: {}", d.message),
            (Some(f), None) => format!("{f}: {}", d.message),
            _ => d.message.clone(),
        })
        .collect();
    checks.push(Check {
        name: "validate".into(),
        status: if v.ok { Status::Pass } else { Status::Fail },
        detail: if v.ok { format!("{} pass(es), {} param(s), {} signal(s)", v.passes.len(), m.params.len(), m.signals.len()) } else { errors.join("; ") },
    });
    for p in &m.params {
        if p.id.len() > 24 || p.label.as_deref().map(|l| l.len() > 24).unwrap_or(false) {
            checks.push(Check { name: format!("naming:{}", p.id), status: Status::Warn, detail: "id/label longer than 24 chars; hosts truncate".into() });
        }
    }
    if !v.ok {
        return Ok(finish(report, checks, None));
    }

    let compiled = match pollster::block_on(host.compile(&plugin)) {
        Ok(c) => c,
        Err(e) => {
            checks.push(Check { name: "compile".into(), status: Status::Fail, detail: format!("{e:#}") });
            return Ok(finish(report, checks, None));
        }
    };
    checks.push(Check { name: "compile".into(), status: Status::Pass, detail: format!("{} pipeline(s) on {}", compiled.passes.len(), host.adapter_name) });

    let inputs = inputs_for(m.kind, &tuning)?;
    let mut list = cases(m, &tuning, !opts.no_perf);
    let mut renders: Vec<Option<Rendered>> = Vec::with_capacity(list.len());
    for c in list.iter_mut() {
        match render_case(host, &compiled, m, &inputs, c) {
            Ok((r, ms)) => {
                let path = out_dir.join(format!("{}.png", c.name));
                r.image.save_png(&path)?;
                c.path = Some(path.display().to_string());
                c.ms = Some(ms);
                if c.role != Role::Perf {
                    frame_checks(&c.name, &r.frame, &mut checks);
                }
                renders.push(Some(r));
            }
            Err(e) => {
                checks.push(Check { name: format!("render:{}", c.name), status: Status::Fail, detail: format!("{e:#}") });
                renders.push(None);
            }
        }
    }

    let find = |role: &Role| -> Option<&Rendered> {
        list.iter().zip(&renders).find(|(c, _)| &c.role == role).and_then(|(_, r)| r.as_ref())
    };
    let baseline = find(&Role::Baseline);

    // Determinism.
    if let (Some(b), Some(r)) = (baseline, find(&Role::Repeat)) {
        let same = b.image.rgba8 == r.image.rgba8;
        checks.push(Check {
            name: "deterministic".into(),
            status: if same { Status::Pass } else { Status::Fail },
            detail: if same { "repeat render is byte-identical".into() } else { format!("repeat differs (mean {:.2}/255)", mean_abs_diff(&b.image.rgba8, &r.image.rgba8)) },
        });
    }

    // Time animation (informational).
    if let (Some(b), Some(t)) = (baseline, find(&Role::Time)) {
        let diff = mean_abs_diff(&b.image.rgba8, &t.image.rgba8);
        report.animated = Some(diff > LIVE_MEAN_DIFF);
        checks.push(Check {
            name: "time".into(),
            status: Status::Pass,
            detail: if diff > LIVE_MEAN_DIFF { format!("animates with time (mean {diff:.2}/255 at t={TIME_LATER})") } else { "static in time".into() },
        });
    }

    // Blank / flat output.
    if let Some(b) = baseline {
        let px: Vec<&[u8]> = b.image.rgba8.chunks_exact(4).collect();
        let all_transparent = px.iter().all(|p| p[3] == 0);
        let flat = px.windows(2).all(|w| w[0] == w[1]);
        let (status, detail) = if all_transparent {
            (Status::Fail, "default render is fully transparent".to_string())
        } else if flat {
            let st = if tuning.flat { Status::Pass } else if m.kind == Kind::Generator { Status::Warn } else { Status::Fail };
            (st, format!("default render is one flat colour {:?}", &px[0]))
        } else {
            (Status::Pass, "default render has content".to_string())
        };
        checks.push(Check { name: "not-blank".into(), status, detail });
    }

    // Transition endpoints.
    if m.kind == Kind::Transition {
        for (p, input, label) in [(0.0f32, "from", "progress 0 == from"), (1.0, "to", "progress 1 == to")] {
            if let Some(r) = find(&Role::Progress(p)) {
                let want = &inputs[input].rgba8;
                let d = max_abs_diff(&r.image.rgba8, want);
                checks.push(Check {
                    name: format!("endpoint:{p:.0}"),
                    status: if d <= ENDPOINT_MAX_DIFF { Status::Pass } else { Status::Fail },
                    detail: format!("{label}: max diff {d}/255 (tolerance {ENDPOINT_MAX_DIFF})"),
                });
            }
        }
        // Monotone-ish: the picture should move away from `from` as progress grows.
        let mut prev = -1.0f32;
        let mut monotone = true;
        if let Some(from) = inputs.get("from") {
            for p in [0.0f32, 0.25, 0.5, 0.75, 1.0] {
                if let Some(r) = find(&Role::Progress(p)) {
                    let d = mean_abs_diff(&r.image.rgba8, &from.rgba8);
                    if d + 0.5 < prev { monotone = false; }
                    prev = prev.max(d);
                }
            }
        }
        checks.push(Check {
            name: "progression".into(),
            status: if monotone { Status::Pass } else { Status::Warn },
            detail: if monotone { "distance from `from` never decreases across progress".into() } else { "distance from `from` decreases somewhere across progress (fine for a dip/flash, otherwise suspicious)".into() },
        });
    }

    // Param and signal liveness.
    let by_name = |name: &str| -> Option<&Rendered> {
        list.iter().zip(&renders).find(|(c, _)| c.name == name).and_then(|(_, r)| r.as_ref())
    };
    if let Some(b) = baseline {
        let mut per_param: BTreeMap<String, f32> = BTreeMap::new();
        for (c, r) in list.iter().zip(&renders) {
            let id = match &c.role {
                Role::Param(id) | Role::Signal(id) => id,
                _ => continue,
            };
            let against = c.baseline.as_deref().and_then(by_name).unwrap_or(b);
            if let Some(r) = r {
                let d = mean_abs_diff(&against.image.rgba8, &r.image.rgba8);
                let e = per_param.entry(id.clone()).or_insert(0.0);
                *e = e.max(d);
            }
        }
        for p in m.params.iter().map(|p| &p.id).chain(m.signals.iter().map(|s| &s.id)) {
            let Some(d) = per_param.get(p) else { continue };
            let live = *d > LIVE_MEAN_DIFF;
            let inert = tuning.inert.iter().any(|i| i == p);
            let (status, detail) = if live {
                (Status::Pass, format!("live (mean {d:.2}/255 from defaults)"))
            } else if inert {
                (Status::Pass, "no effect on the default render (declared inert in verify.json)".into())
            } else {
                (Status::Fail, format!("no visible effect on the default render (mean {d:.2}/255); unused field, wrong struct order, or an inert default?"))
            };
            checks.push(Check { name: format!("live:{p}"), status, detail });
        }
    }

    // Identity.
    if let (Some(r), Some(src)) = (find(&Role::Identity), inputs.get("source")) {
        let d = max_abs_diff(&r.image.rgba8, &src.rgba8);
        checks.push(Check {
            name: "identity".into(),
            status: if d <= ENDPOINT_MAX_DIFF { Status::Pass } else { Status::Fail },
            detail: format!("identity params reproduce the source: max diff {d}/255 (tolerance {ENDPOINT_MAX_DIFF})"),
        });
    }

    // Perf.
    if let Some(c) = list.iter().find(|c| c.role == Role::Perf) {
        if let Some(ms) = c.ms {
            let slow = ms > PERF_WARN_MS && !report.software_gpu;
            checks.push(Check {
                name: "perf".into(),
                status: if slow { Status::Warn } else { Status::Pass },
                detail: format!("{}x{} in {ms:.1} ms on {}{}", c.width, c.height, host.adapter_name, if report.software_gpu { " (software; not representative)" } else { "" }),
            });
        }
    }

    // Contact sheet and assets.
    let sheet_cells: Vec<(String, Image)> = {
        let mut cells: Vec<(String, Image)> = Vec::new();
        for name in ["source", "from", "to"] {
            if let Some(i) = inputs.get(name) {
                cells.push((format!("in:{name}"), i.clone()));
            }
        }
        for (c, r) in list.iter().zip(&renders) {
            if c.role == Role::Perf || c.role == Role::Repeat {
                continue;
            }
            if let Some(r) = r {
                cells.push((c.name.clone(), r.image.clone()));
            }
        }
        cells
    };
    let sheet_path = out_dir.join("sheet.png");
    sheet::write_sheet(&sheet_path, &format!("{}@{} ({:?}) on {}", m.id, m.version, m.kind, host.adapter_name), &sheet_cells, CASE_SIZE, 4)?;
    report.sheet = Some(sheet_path.display().to_string());

    if opts.assets {
        let mut c = list.iter().find(|c| c.role == Role::Baseline).cloned().expect("baseline case exists");
        c.width = PREVIEW_SIZE.0;
        c.height = PREVIEW_SIZE.1;
        c.progress = 0.5;
        let (r, _) = render_case(host, &compiled, m, &inputs, &c)?;
        r.image.save_png(&dir.join("preview.png"))?;
        sheet::icon_from(&r.image, ICON_SIZE).save_png(&dir.join("icon.png"))?;
        checks.push(Check { name: "assets".into(), status: Status::Pass, detail: "wrote preview.png (512×288) and icon.png (128×128)".into() });
    }

    report.cases = list;
    Ok(finish(report, checks, None))
}

fn finish(mut report: Report, checks: Vec<Check>, _: Option<()>) -> Report {
    let mut s = Summary { pass: 0, warn: 0, fail: 0 };
    for c in &checks {
        match c.status {
            Status::Pass => s.pass += 1,
            Status::Warn => s.warn += 1,
            Status::Fail => s.fail += 1,
        }
    }
    report.ok = s.fail == 0;
    report.summary = s;
    report.checks = checks;
    report
}

/// Write `report.json` next to the cases.
pub fn write_report(report: &Report) -> Result<PathBuf> {
    let path = Path::new(&report.out_dir).join("report.json");
    std::fs::write(&path, serde_json::to_string_pretty(report)?).with_context(|| format!("writing {}", path.display()))?;
    Ok(path)
}

// ── Contact sheet ────────────────────────────────────────────────────

pub mod sheet {
    use super::*;

    /// 5×7 glyphs for printable ASCII 32..=126, one byte per column, LSB = top row.
    const FONT: [[u8; 5]; 95] = [
        [0x00,0x00,0x00,0x00,0x00],[0x00,0x00,0x5f,0x00,0x00],[0x00,0x07,0x00,0x07,0x00],[0x14,0x7f,0x14,0x7f,0x14],
        [0x24,0x2a,0x7f,0x2a,0x12],[0x23,0x13,0x08,0x64,0x62],[0x36,0x49,0x55,0x22,0x50],[0x00,0x05,0x03,0x00,0x00],
        [0x00,0x1c,0x22,0x41,0x00],[0x00,0x41,0x22,0x1c,0x00],[0x14,0x08,0x3e,0x08,0x14],[0x08,0x08,0x3e,0x08,0x08],
        [0x00,0x50,0x30,0x00,0x00],[0x08,0x08,0x08,0x08,0x08],[0x00,0x60,0x60,0x00,0x00],[0x20,0x10,0x08,0x04,0x02],
        [0x3e,0x51,0x49,0x45,0x3e],[0x00,0x42,0x7f,0x40,0x00],[0x42,0x61,0x51,0x49,0x46],[0x21,0x41,0x45,0x4b,0x31],
        [0x18,0x14,0x12,0x7f,0x10],[0x27,0x45,0x45,0x45,0x39],[0x3c,0x4a,0x49,0x49,0x30],[0x01,0x71,0x09,0x05,0x03],
        [0x36,0x49,0x49,0x49,0x36],[0x06,0x49,0x49,0x29,0x1e],[0x00,0x36,0x36,0x00,0x00],[0x00,0x56,0x36,0x00,0x00],
        [0x08,0x14,0x22,0x41,0x00],[0x14,0x14,0x14,0x14,0x14],[0x00,0x41,0x22,0x14,0x08],[0x02,0x01,0x51,0x09,0x06],
        [0x32,0x49,0x79,0x41,0x3e],[0x7e,0x11,0x11,0x11,0x7e],[0x7f,0x49,0x49,0x49,0x36],[0x3e,0x41,0x41,0x41,0x22],
        [0x7f,0x41,0x41,0x22,0x1c],[0x7f,0x49,0x49,0x49,0x41],[0x7f,0x09,0x09,0x09,0x01],[0x3e,0x41,0x49,0x49,0x7a],
        [0x7f,0x08,0x08,0x08,0x7f],[0x00,0x41,0x7f,0x41,0x00],[0x20,0x40,0x41,0x3f,0x01],[0x7f,0x08,0x14,0x22,0x41],
        [0x7f,0x40,0x40,0x40,0x40],[0x7f,0x02,0x0c,0x02,0x7f],[0x7f,0x04,0x08,0x10,0x7f],[0x3e,0x41,0x41,0x41,0x3e],
        [0x7f,0x09,0x09,0x09,0x06],[0x3e,0x41,0x51,0x21,0x5e],[0x7f,0x09,0x19,0x29,0x46],[0x46,0x49,0x49,0x49,0x31],
        [0x01,0x01,0x7f,0x01,0x01],[0x3f,0x40,0x40,0x40,0x3f],[0x1f,0x20,0x40,0x20,0x1f],[0x3f,0x40,0x38,0x40,0x3f],
        [0x63,0x14,0x08,0x14,0x63],[0x07,0x08,0x70,0x08,0x07],[0x61,0x51,0x49,0x45,0x43],[0x00,0x7f,0x41,0x41,0x00],
        [0x02,0x04,0x08,0x10,0x20],[0x00,0x41,0x41,0x7f,0x00],[0x04,0x02,0x01,0x02,0x04],[0x40,0x40,0x40,0x40,0x40],
        [0x00,0x01,0x02,0x04,0x00],[0x20,0x54,0x54,0x54,0x78],[0x7f,0x48,0x44,0x44,0x38],[0x38,0x44,0x44,0x44,0x20],
        [0x38,0x44,0x44,0x48,0x7f],[0x38,0x54,0x54,0x54,0x18],[0x08,0x7e,0x09,0x01,0x02],[0x0c,0x52,0x52,0x52,0x3e],
        [0x7f,0x08,0x04,0x04,0x78],[0x00,0x44,0x7d,0x40,0x00],[0x20,0x40,0x44,0x3d,0x00],[0x7f,0x10,0x28,0x44,0x00],
        [0x00,0x41,0x7f,0x40,0x00],[0x7c,0x04,0x18,0x04,0x78],[0x7c,0x08,0x04,0x04,0x78],[0x38,0x44,0x44,0x44,0x38],
        [0x7c,0x14,0x14,0x14,0x08],[0x08,0x14,0x14,0x18,0x7c],[0x7c,0x08,0x04,0x04,0x08],[0x48,0x54,0x54,0x54,0x20],
        [0x04,0x3f,0x44,0x40,0x20],[0x3c,0x40,0x40,0x20,0x7c],[0x1c,0x20,0x40,0x20,0x1c],[0x3c,0x40,0x30,0x40,0x3c],
        [0x44,0x28,0x10,0x28,0x44],[0x0c,0x50,0x50,0x50,0x3c],[0x44,0x64,0x54,0x4c,0x44],[0x00,0x08,0x36,0x41,0x00],
        [0x00,0x00,0x7f,0x00,0x00],[0x00,0x41,0x36,0x08,0x00],[0x10,0x08,0x08,0x10,0x08],
    ];

    pub struct Canvas {
        pub width: u32,
        pub height: u32,
        pub rgba8: Vec<u8>,
    }

    impl Canvas {
        pub fn new(width: u32, height: u32, bg: [u8; 4]) -> Canvas {
            let mut rgba8 = Vec::with_capacity((width * height * 4) as usize);
            for _ in 0..width * height {
                rgba8.extend_from_slice(&bg);
            }
            Canvas { width, height, rgba8 }
        }

        pub fn put(&mut self, x: i64, y: i64, c: [u8; 4]) {
            if x < 0 || y < 0 || x >= self.width as i64 || y >= self.height as i64 {
                return;
            }
            let i = ((y as u32 * self.width + x as u32) * 4) as usize;
            self.rgba8[i..i + 4].copy_from_slice(&c);
        }

        /// Draw `text` at `scale`× (glyph cell 6×8 at 1×).
        pub fn text(&mut self, x: i64, y: i64, text: &str, scale: u32, c: [u8; 4]) {
            let mut cx = x;
            for ch in text.chars() {
                let idx = (ch as u32).saturating_sub(32) as usize;
                let glyph = FONT.get(idx).copied().unwrap_or(FONT[31]); // '?'
                for (col, bits) in glyph.iter().enumerate() {
                    for row in 0..7 {
                        if bits >> row & 1 == 1 {
                            for dy in 0..scale {
                                for dx in 0..scale {
                                    self.put(cx + (col as u32 * scale + dx) as i64, y + (row * scale + dy) as i64, c);
                                }
                            }
                        }
                    }
                }
                cx += (6 * scale) as i64;
            }
        }

        /// Blit an image over a checkerboard (so transparency reads as such), scaled to fit `cell`.
        pub fn image(&mut self, x: i64, y: i64, img: &Image, cell: (u32, u32)) {
            let (cw, ch) = cell;
            let scale = (cw as f32 / img.width as f32).min(ch as f32 / img.height as f32);
            let dw = ((img.width as f32 * scale) as u32).max(1);
            let dh = ((img.height as f32 * scale) as u32).max(1);
            for dy in 0..dh {
                for dx in 0..dw {
                    let sx = ((dx as f32 / scale) as u32).min(img.width - 1);
                    let sy = ((dy as f32 / scale) as u32).min(img.height - 1);
                    let i = ((sy * img.width + sx) * 4) as usize;
                    let p = &img.rgba8[i..i + 4];
                    let checker = if ((dx / 8) + (dy / 8)) % 2 == 0 { 96u8 } else { 128u8 };
                    let a = p[3] as u32;
                    let blend = |c: u8| ((c as u32 * a + checker as u32 * (255 - a)) / 255) as u8;
                    self.put(x + dx as i64, y + dy as i64, [blend(p[0]), blend(p[1]), blend(p[2]), 255]);
                }
            }
        }

        pub fn rect(&mut self, x: i64, y: i64, w: u32, h: u32, c: [u8; 4]) {
            for i in 0..w as i64 {
                self.put(x + i, y, c);
                self.put(x + i, y + h as i64 - 1, c);
            }
            for j in 0..h as i64 {
                self.put(x, y + j, c);
                self.put(x + w as i64 - 1, y + j, c);
            }
        }

        pub fn save_png(&self, path: &Path) -> Result<()> {
            image::save_buffer(path, &self.rgba8, self.width, self.height, image::ColorType::Rgba8)
                .with_context(|| format!("writing {}", path.display()))
        }
    }

    pub const LABEL_H: u32 = 18;
    pub const PAD: u32 = 6;
    pub const TITLE_H: u32 = 24;

    /// A grid of labelled cells, `cols` per row.
    pub fn write_sheet(path: &Path, title: &str, cells: &[(String, Image)], cell: (u32, u32), cols: u32) -> Result<()> {
        let cols = cols.max(1);
        let rows = (cells.len() as u32).div_ceil(cols).max(1);
        let w = PAD + cols * (cell.0 + PAD);
        let h = TITLE_H + rows * (cell.1 + LABEL_H + PAD) + PAD;
        let mut c = Canvas::new(w, h, [24, 24, 28, 255]);
        c.text(PAD as i64, 6, title, 2, [230, 230, 230, 255]);
        for (i, (label, img)) in cells.iter().enumerate() {
            let col = i as u32 % cols;
            let row = i as u32 / cols;
            let x = (PAD + col * (cell.0 + PAD)) as i64;
            let y = (TITLE_H + row * (cell.1 + LABEL_H + PAD)) as i64;
            let max_chars = (cell.0 / 12) as usize;
            let short: String = label.chars().take(max_chars).collect();
            c.text(x, y + 2, &short, 2, [200, 200, 160, 255]);
            c.image(x, y + LABEL_H as i64, img, cell);
            c.rect(x - 1, y + LABEL_H as i64 - 1, cell.0 + 2, cell.1 + 2, [60, 60, 70, 255]);
        }
        c.save_png(path)
    }

    /// Status-coloured overview: one labelled cell per plugin.
    pub fn write_overview(path: &Path, title: &str, cells: &[(String, Status, Image)], cell: (u32, u32), cols: u32) -> Result<()> {
        let cols = cols.max(1);
        let rows = (cells.len() as u32).div_ceil(cols).max(1);
        let w = PAD + cols * (cell.0 + PAD);
        let h = TITLE_H + rows * (cell.1 + LABEL_H + PAD) + PAD;
        let mut c = Canvas::new(w, h, [24, 24, 28, 255]);
        c.text(PAD as i64, 6, title, 2, [230, 230, 230, 255]);
        for (i, (label, status, img)) in cells.iter().enumerate() {
            let col = i as u32 % cols;
            let row = i as u32 / cols;
            let x = (PAD + col * (cell.0 + PAD)) as i64;
            let y = (TITLE_H + row * (cell.1 + LABEL_H + PAD)) as i64;
            let max_chars = (cell.0 / 12) as usize;
            let short: String = label.chars().take(max_chars).collect();
            let colour = match status {
                Status::Pass => [90, 200, 110, 255],
                Status::Warn => [230, 170, 60, 255],
                Status::Fail => [230, 70, 70, 255],
            };
            c.text(x, y + 2, &short, 2, colour);
            c.image(x, y + LABEL_H as i64, img, cell);
            c.rect(x - 2, y + LABEL_H as i64 - 2, cell.0 + 4, cell.1 + 4, colour);
            c.rect(x - 1, y + LABEL_H as i64 - 1, cell.0 + 2, cell.1 + 2, colour);
        }
        c.save_png(path)
    }

    /// Square centre crop of `img`, resized to `size` (box filter).
    pub fn icon_from(img: &Image, size: u32) -> Image {
        let side = img.width.min(img.height);
        let x0 = (img.width - side) / 2;
        let y0 = (img.height - side) / 2;
        let buf = image::RgbaImage::from_raw(img.width, img.height, img.rgba8.clone()).expect("image buffer");
        let cropped = image::imageops::crop_imm(&buf, x0, y0, side, side).to_image();
        let resized = image::imageops::resize(&cropped, size, size, image::imageops::FilterType::Triangle);
        Image { width: size, height: size, rgba8: resized.into_raw() }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn manifest(json: &str) -> Manifest {
        serde_json::from_str(json).unwrap()
    }

    const TRANSITION: &str = r#"{
        "gobofx": "0.1", "id": "org.test.t", "name": "T", "kind": "transition", "version": "1.0.0",
        "params": [
            { "id": "direction", "type": "choice", "default": 0, "options": ["a", "b", "c"] },
            { "id": "softness", "type": "float", "default": 0.05, "min": 0.0, "max": 0.5 },
            { "id": "ease", "type": "float", "default": 0.0, "min": 0.0, "max": 1.0 },
            { "id": "flag", "type": "bool", "default": false },
            { "id": "tint", "type": "color", "default": [0, 1, 0, 1] },
            { "id": "center", "type": "point", "default": [0.5, 0.5] }
        ],
        "signals": [ { "id": "wobble", "cc": 1 } ],
        "passes": [ { "shader": "s.wgsl", "entry": "fs", "inputs": ["from", "to"], "output": "out" } ]
    }"#;

    #[test]
    fn matrix_covers_every_param_and_endpoint() {
        let m = manifest(TRANSITION);
        let cs = cases(&m, &Tuning::default(), true);
        let names: Vec<&str> = cs.iter().map(|c| c.name.as_str()).collect();
        assert!(names.contains(&"defaults"));
        assert!(names.contains(&"repeat"));
        assert!(names.contains(&"progress-0.00"));
        assert!(names.contains(&"progress-1.00"));
        // choice: the two non-default options; float min skipped when equal to default
        assert!(names.contains(&"p-direction-b") && names.contains(&"p-direction-c") && !names.contains(&"p-direction-a"));
        assert!(names.contains(&"p-softness-min") && names.contains(&"p-softness-max"));
        assert!(!names.contains(&"p-ease-min") && names.contains(&"p-ease-max"));
        assert!(names.contains(&"p-flag-on"));
        // colour default is green, so the sweep picks magenta
        let tint = cs.iter().find(|c| c.name == "p-tint-magenta").unwrap();
        assert_eq!(tint.params["tint"], "1,0,1,1");
        assert!(names.contains(&"p-center-tl"));
        assert!(names.contains(&"s-wobble"));
        assert!(!names.contains(&"s-wobble-off"), "single signal has no -off variant");
        let sig = cs.iter().find(|c| c.name == "p-softness-max+1").unwrap();
        assert!(sig.baseline.as_deref() == Some("signals-on") && sig.signals["wobble"] == "1");
        assert!(names.contains(&"signals-on") && names.contains(&"signals-half") && names.contains(&"s-wobble-half"));
        assert!(names.contains(&"perf"));
        // sweeps run at the off-centre progress, endpoints at their own
        assert_eq!(cs.iter().find(|c| c.name == "p-ease-max").unwrap().progress, SWEEP_PROGRESS);
        assert_eq!(cs.iter().find(|c| c.name == "progress-1.00").unwrap().progress, 1.0);
        // no case is identical to the baseline by construction
        for c in &cs {
            if matches!(c.role, Role::Param(_)) {
                assert!(!c.params.is_empty(), "{}", c.name);
            }
        }
    }

    #[test]
    fn sweep_values_round_trip_through_the_param_parser() {
        let m = manifest(TRANSITION);
        for p in &m.params {
            for (_, text) in sweep_values(p) {
                params::parse_value(p, &text).unwrap();
            }
        }
    }

    #[test]
    fn identity_case_only_for_effects() {
        let m = manifest(&TRANSITION.replace("\"transition\"", "\"effect\"").replace("[\"from\", \"to\"]", "[\"source\"]"));
        let mut t = Tuning::default();
        t.identity.insert("softness".into(), "0".into());
        assert!(cases(&m, &t, false).iter().any(|c| c.role == Role::Identity));
        let m2 = manifest(TRANSITION);
        assert!(!cases(&m2, &t, false).iter().any(|c| c.role == Role::Identity));
    }

    #[test]
    fn diffs() {
        assert_eq!(mean_abs_diff(&[0, 0, 0, 0], &[0, 0, 0, 0]), 0.0);
        assert_eq!(mean_abs_diff(&[0, 10, 0, 0], &[0, 0, 0, 0]), 2.5);
        assert_eq!(max_abs_diff(&[0, 10, 0, 0], &[0, 0, 0, 1]), 10);
        assert!(mean_abs_diff(&[0], &[0, 1]).is_infinite());
    }

    #[test]
    fn font_renders_every_ascii_glyph() {
        let mut c = sheet::Canvas::new(600, 20, [0, 0, 0, 255]);
        let all: String = (32u8..127).map(|b| b as char).collect();
        c.text(0, 0, &all, 1, [255, 255, 255, 255]);
        assert!(c.rgba8.iter().any(|v| *v == 255));
    }

    #[test]
    fn icon_is_a_square_of_the_requested_size() {
        let img = Image { width: 64, height: 32, rgba8: vec![200; 64 * 32 * 4] };
        let icon = sheet::icon_from(&img, 16);
        assert_eq!((icon.width, icon.height), (16, 16));
        assert_eq!(icon.rgba8.len(), 16 * 16 * 4);
    }
}
