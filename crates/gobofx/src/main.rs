//! `gobofx` — test tool for GoboFX plugins. Made for people and for agents:
//! every command has a `--json` form, exit codes are meaningful, and `render`
//! writes PNGs that can be looked at.
//!
//! Exit codes: 0 ok · 1 the plugin failed validation or rendering · 2 bad usage / IO.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::process::ExitCode;

use anyhow::{anyhow, bail, Context, Result};
use clap::{Args, Parser, Subcommand};
use serde::Serialize;

use gobofx::manifest::{Kind, Plugin};
use gobofx::params;
use gobofx::render::{Globals, Host, Image};
use gobofx::validate::{self, Level};

#[derive(Parser)]
#[command(name = "gobofx", version, about = "Validate and render GoboFX plugins headlessly.")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Validate a plugin: manifest rules, pass graph, and every shader through naga.
    Check {
        /// Plugin folder containing manifest.json
        dir: PathBuf,
        /// Machine-readable report
        #[arg(long)]
        json: bool,
    },
    /// Print the manifest, params layout and pass list as JSON (always validates first).
    Info {
        /// Plugin folder containing manifest.json
        dir: PathBuf,
    },
    /// Render the plugin to PNG on the GPU (validates first).
    Render(RenderArgs),
    /// Render a case matrix derived from the manifest, check the contracts
    /// (endpoints, param liveness, determinism, finite output …) and write
    /// `report.json` + a labelled `sheet.png` per plugin. Exit 1 on any failed check.
    Verify(VerifyArgs),
    /// Pack a plugin folder into a `.gobofx` package (validates first).
    /// Prints the package path; default `<dir>/dist/<id>-<version>.gobofx`.
    Pack {
        /// Plugin folder containing manifest.json
        dir: PathBuf,
        /// Output file (default: <dir>/dist/<id>-<version>.gobofx)
        #[arg(short, long)]
        out: Option<PathBuf>,
        /// Machine-readable summary
        #[arg(long)]
        json: bool,
    },
}

#[derive(Args)]
struct RenderArgs {
    /// Plugin folder containing manifest.json
    dir: PathBuf,
    /// Input PNG. Effects take one (source); transitions take two (from, then to); generators take none.
    #[arg(short, long = "input")]
    inputs: Vec<PathBuf>,
    /// Output PNG (single frame)
    #[arg(short, long, default_value = "out.png")]
    output: PathBuf,
    /// Progress 0..1 (transition position, or position across the clip for an effect)
    #[arg(long, default_value_t = 0.5)]
    progress: f32,
    /// Time in seconds since clip start
    #[arg(long, default_value_t = 0.0)]
    time: f32,
    /// Param override, `id=value`. Repeatable. Colors `r,g,b,a`, points `x,y`, choices by index or name.
    #[arg(short = 'p', long = "param")]
    params: Vec<String>,
    /// Signal value, `id=value` in 0..1 (a MIDI 2.0 controller or note level). Repeatable.
    #[arg(short = 's', long = "signal")]
    signals: Vec<String>,
    /// Output size `WxH` (default: size of the first input)
    #[arg(long)]
    size: Option<String>,
    /// Render N frames with progress 0..1 into --out-dir instead of one frame
    #[arg(long)]
    steps: Option<u32>,
    /// Folder for --steps frames (frame_000.png …)
    #[arg(long, default_value = "frames")]
    out_dir: PathBuf,
    /// Machine-readable summary
    #[arg(long)]
    json: bool,
}

#[derive(Args)]
struct VerifyArgs {
    /// Plugin folder(s) containing manifest.json
    dirs: Vec<PathBuf>,
    /// Output folder for one plugin (default: <dir>/dist/verify). With several plugins, each keeps its own.
    #[arg(long)]
    out_dir: Option<PathBuf>,
    /// Where the multi-plugin `index.json` and `all.png` overview go
    #[arg(long, default_value = "dist/verify")]
    summary_dir: PathBuf,
    /// Also write `preview.png` (512×288) and `icon.png` (128×128) into each plugin folder
    #[arg(long)]
    assets: bool,
    /// Skip the 1280×720 timed render
    #[arg(long)]
    no_perf: bool,
    /// Machine-readable report (one plugin: the report; several: the index)
    #[arg(long)]
    json: bool,
}

#[derive(Serialize)]
struct RenderSummary<'a> {
    ok: bool,
    id: &'a str,
    adapter: &'a str,
    backend: &'a str,
    width: u32,
    height: u32,
    params: Vec<ParamOut<'a>>,
    signals: Vec<SignalOut<'a>>,
    frames: Vec<FrameOut>,
}

#[derive(Serialize)]
struct SignalOut<'a> {
    id: &'a str,
    value: f32,
}

#[derive(Serialize)]
struct ParamOut<'a> {
    id: &'a str,
    value: &'a params::Value,
}

#[derive(Serialize)]
struct FrameOut {
    progress: f32,
    time: f32,
    path: String,
}

fn main() -> ExitCode {
    match run() {
        Ok(code) => code,
        Err(e) => {
            eprintln!("error: {e:#}");
            ExitCode::from(2)
        }
    }
}

fn run() -> Result<ExitCode> {
    let cli = Cli::parse();
    match cli.cmd {
        Cmd::Check { dir, json } => {
            let plugin = Plugin::load(&dir)?;
            let report = validate::validate(&plugin);
            if json {
                println!("{}", serde_json::to_string_pretty(&report)?);
            } else {
                print_report(&report, &dir);
            }
            Ok(if report.ok { ExitCode::SUCCESS } else { ExitCode::from(1) })
        }
        Cmd::Info { dir } => {
            let plugin = Plugin::load(&dir)?;
            let report = validate::validate(&plugin);
            #[derive(Serialize)]
            struct Info<'a> {
                manifest: &'a gobofx::manifest::Manifest,
                report: &'a validate::Report,
            }
            println!("{}", serde_json::to_string_pretty(&Info { manifest: &plugin.manifest, report: &report })?);
            Ok(if report.ok { ExitCode::SUCCESS } else { ExitCode::from(1) })
        }
        Cmd::Render(args) => render(args),
        Cmd::Verify(args) => verify(args),
        Cmd::Pack { dir, out, json } => {
            let plugin = Plugin::load(&dir)?;
            let report = validate::validate(&plugin);
            if !report.ok {
                print_report(&report, &dir);
                return Ok(ExitCode::from(1));
            }
            let entries = gobofx::pack::collect_entries(&plugin)?;
            let bytes = gobofx::pack::write_zip(&entries)?;
            let path = out.unwrap_or_else(|| dir.join("dist").join(gobofx::pack::package_file_name(&plugin)));
            if let Some(parent) = path.parent() {
                std::fs::create_dir_all(parent).with_context(|| format!("creating {}", parent.display()))?;
            }
            std::fs::write(&path, &bytes).with_context(|| format!("writing {}", path.display()))?;
            if json {
                #[derive(Serialize)]
                struct Out<'a> { ok: bool, id: &'a str, version: &'a str, path: String, bytes: usize, entries: Vec<&'a str> }
                println!("{}", serde_json::to_string_pretty(&Out {
                    ok: true,
                    id: &plugin.manifest.id,
                    version: &plugin.manifest.version,
                    path: path.display().to_string(),
                    bytes: bytes.len(),
                    entries: entries.iter().map(|e| e.name.as_str()).collect(),
                })?);
            } else {
                println!("{}", path.display());
            }
            Ok(ExitCode::SUCCESS)
        }
    }
}

fn print_report(report: &validate::Report, dir: &std::path::Path) {
    println!(
        "{} {}@{} ({:?}, {} pass{}, {} param{})",
        if report.ok { "OK  " } else { "FAIL" },
        report.id,
        report.version,
        report.kind,
        report.passes.len(),
        if report.passes.len() == 1 { "" } else { "es" },
        report.params.fields.len(),
        if report.params.fields.len() == 1 { "" } else { "s" },
    );
    for d in &report.diagnostics {
        let level = match d.level {
            Level::Error => "error",
            Level::Warning => "warning",
        };
        let mut loc = String::new();
        if let Some(f) = &d.file {
            loc.push_str(&dir.join(f).display().to_string());
            if let Some(l) = d.line {
                loc.push_str(&format!(":{l}"));
            }
            loc.push_str(": ");
        } else if let Some(p) = d.pass {
            loc.push_str(&format!("pass {p}: "));
        }
        println!("  {level}: {loc}{}", d.message);
    }
}

fn render(args: RenderArgs) -> Result<ExitCode> {
    let plugin = Plugin::load(&args.dir)?;
    let report = validate::validate(&plugin);
    if !report.ok {
        print_report(&report, &args.dir);
        return Ok(ExitCode::from(1));
    }
    let m = &plugin.manifest;

    let needed = m.kind.reserved_inputs();
    if args.inputs.len() != needed.len() {
        bail!(
            "{:?} plugin takes {} input{} ({}), got {}",
            m.kind,
            needed.len(),
            if needed.len() == 1 { "" } else { "s" },
            needed.join(", "),
            args.inputs.len()
        );
    }
    let mut inputs = BTreeMap::new();
    for (name, path) in needed.iter().zip(&args.inputs) {
        inputs.insert(name.to_string(), Image::load_png(path)?);
    }
    let first = match m.kind {
        Kind::Effect => inputs.get("source"),
        Kind::Transition => inputs.get("from"),
        Kind::Generator => None,
    };
    let size = match &args.size {
        Some(s) => {
            let (w, h) = s.split_once('x').ok_or_else(|| anyhow!("--size must be WxH"))?;
            (w.parse::<u32>().context("--size width")?, h.parse::<u32>().context("--size height")?)
        }
        None => first.map(|i| (i.width, i.height)).unwrap_or((1280, 720)),
    };

    let mut overrides = BTreeMap::new();
    for p in &args.params {
        let (k, v) = p.split_once('=').ok_or_else(|| anyhow!("--param must be id=value, got '{p}'"))?;
        overrides.insert(k.trim().to_string(), v.to_string());
    }
    let values = params::resolve(m, &overrides)?;
    let mut signal_overrides = BTreeMap::new();
    for s in &args.signals {
        let (k, v) = s.split_once('=').ok_or_else(|| anyhow!("--signal must be id=value, got '{s}'"))?;
        signal_overrides.insert(k.trim().to_string(), v.to_string());
    }
    let signal_values = params::resolve_signals(m, &signal_overrides)?;

    let host = Host::new()?;
    let compiled = pollster::block_on(host.compile(&plugin))?;
    let mut frames = Vec::new();
    let result: Result<()> = (|| {
        match args.steps {
            Some(n) if n >= 1 => {
                std::fs::create_dir_all(&args.out_dir)?;
                for i in 0..n {
                    let progress = if n == 1 { args.progress } else { i as f32 / (n - 1) as f32 };
                    let img = host.render_image(&compiled, &inputs, size, Globals { time: args.time, progress }, &values, &signal_values)?;
                    let path = args.out_dir.join(format!("frame_{i:03}.png"));
                    img.save_png(&path)?;
                    frames.push(FrameOut { progress, time: args.time, path: path.display().to_string() });
                }
            }
            _ => {
                let img = host.render_image(&compiled, &inputs, size, Globals { time: args.time, progress: args.progress }, &values, &signal_values)?;
                img.save_png(&args.output)?;
                frames.push(FrameOut { progress: args.progress, time: args.time, path: args.output.display().to_string() });
            }
        }
        Ok(())
    })();

    if let Err(e) = result {
        if args.json {
            println!("{}", serde_json::json!({ "ok": false, "id": m.id, "error": format!("{e:#}") }));
        } else {
            eprintln!("render failed: {e:#}");
        }
        return Ok(ExitCode::from(1));
    }

    if args.json {
        let summary = RenderSummary {
            ok: true,
            id: &m.id,
            adapter: &host.adapter_name,
            backend: &host.backend,
            width: size.0,
            height: size.1,
            params: m.params.iter().zip(&values).map(|(p, v)| ParamOut { id: &p.id, value: v }).collect(),
            signals: m.signals.iter().zip(&signal_values).map(|(s, v)| SignalOut { id: &s.id, value: *v }).collect(),
            frames,
        };
        println!("{}", serde_json::to_string_pretty(&summary)?);
    } else {
        println!("OK   {} on {} ({}) {}x{}", m.id, host.adapter_name, host.backend, size.0, size.1);
        for (s, v) in m.signals.iter().zip(&signal_values) {
            println!("  signal {} = {:.3}", s.id, v);
        }
        for f in &frames {
            println!("  progress {:.3} → {}", f.progress, f.path);
        }
    }
    Ok(ExitCode::SUCCESS)
}

fn verify(args: VerifyArgs) -> Result<ExitCode> {
    use gobofx::verify::{self as v, Status};
    if args.dirs.is_empty() {
        bail!("verify needs at least one plugin folder");
    }
    let host = Host::new().context(
        "no GPU adapter; on a headless Linux box run `source tools/gpu-env.sh` first (SwiftShader), or set WGPU_BACKEND",
    )?;
    let opts = v::Options { out_dir: if args.dirs.len() == 1 { args.out_dir.clone() } else { None }, assets: args.assets, no_perf: args.no_perf };

    let mut reports = Vec::new();
    for dir in &args.dirs {
        let report = match v::verify(&host, dir, &opts) {
            Ok(r) => r,
            Err(e) => {
                // A plugin that cannot even be loaded still gets a row, so a batch run reports it.
                eprintln!("{}: {e:#}", dir.display());
                let id = dir.file_name().map(|f| f.to_string_lossy().to_string()).unwrap_or_default();
                let mut r = v::Report {
                    ok: false, id, version: String::new(), kind: Kind::Effect, adapter: host.adapter_name.clone(),
                    backend: host.backend.clone(), software_gpu: false, out_dir: dir.join("dist").join("verify").display().to_string(),
                    cases: vec![], checks: vec![v::Check { name: "load".into(), status: Status::Fail, detail: format!("{e:#}") }],
                    animated: None, summary: v::Summary { pass: 0, warn: 0, fail: 1 }, sheet: None,
                };
                r.ok = false;
                r
            }
        };
        if std::path::Path::new(&report.out_dir).is_dir() {
            v::write_report(&report)?;
        }
        if !args.json || args.dirs.len() > 1 {
            print_verify(&report);
        }
        reports.push(report);
    }

    if args.dirs.len() == 1 {
        if args.json {
            println!("{}", serde_json::to_string_pretty(&reports[0])?);
        }
        return Ok(if reports[0].ok { ExitCode::SUCCESS } else { ExitCode::from(1) });
    }

    // Batch: index + overview sheet.
    std::fs::create_dir_all(&args.summary_dir)?;
    let mut cells = Vec::new();
    for r in &reports {
        let worst = r.checks.iter().map(|c| c.status).max().unwrap_or(Status::Pass);
        let img = r
            .cases
            .iter()
            .find(|c| c.role == v::Role::Baseline)
            .and_then(|c| c.path.as_ref())
            .and_then(|p| Image::load_png(std::path::Path::new(p)).ok())
            .unwrap_or(Image { width: 4, height: 4, rgba8: vec![0; 64] });
        let short = r.id.strip_prefix("org.gobofx.").unwrap_or(&r.id).to_string();
        cells.push((short, worst, img));
    }
    let all_png = args.summary_dir.join("all.png");
    v::sheet::write_overview(&all_png, &format!("{} plugins on {}", reports.len(), host.adapter_name), &cells, v::CASE_SIZE, 5)?;
    #[derive(Serialize)]
    struct Row<'a> { ok: bool, id: &'a str, version: &'a str, kind: Kind, fail: usize, warn: usize, pass: usize, report: String, sheet: Option<&'a str>, failed: Vec<&'a str> }
    #[derive(Serialize)]
    struct Index<'a> { ok: bool, adapter: &'a str, backend: &'a str, software_gpu: bool, overview: String, plugins: Vec<Row<'a>> }
    let index = Index {
        ok: reports.iter().all(|r| r.ok),
        adapter: &host.adapter_name,
        backend: &host.backend,
        software_gpu: reports.first().map(|r| r.software_gpu).unwrap_or(false),
        overview: all_png.display().to_string(),
        plugins: reports
            .iter()
            .map(|r| Row {
                ok: r.ok,
                id: &r.id,
                version: &r.version,
                kind: r.kind,
                fail: r.summary.fail,
                warn: r.summary.warn,
                pass: r.summary.pass,
                report: std::path::Path::new(&r.out_dir).join("report.json").display().to_string(),
                sheet: r.sheet.as_deref(),
                failed: r.checks.iter().filter(|c| c.status == Status::Fail).map(|c| c.name.as_str()).collect(),
            })
            .collect(),
    };
    let index_path = args.summary_dir.join("index.json");
    std::fs::write(&index_path, serde_json::to_string_pretty(&index)?)?;
    if args.json {
        println!("{}", serde_json::to_string_pretty(&index)?);
    } else {
        let failed = reports.iter().filter(|r| !r.ok).count();
        println!(
            "{} {}/{} plugins pass · {} · {}",
            if failed == 0 { "OK  " } else { "FAIL" },
            reports.len() - failed,
            reports.len(),
            index_path.display(),
            all_png.display()
        );
    }
    Ok(if index.ok { ExitCode::SUCCESS } else { ExitCode::from(1) })
}

fn print_verify(r: &gobofx::verify::Report) {
    use gobofx::verify::Status;
    println!(
        "{} {}@{} ({:?}) — {} cases, {} checks: {} pass, {} warn, {} fail{}",
        if r.ok { "OK  " } else { "FAIL" },
        r.id,
        r.version,
        r.kind,
        r.cases.len(),
        r.checks.len(),
        r.summary.pass,
        r.summary.warn,
        r.summary.fail,
        r.animated.map(|a| if a { " · animated" } else { " · static" }).unwrap_or(""),
    );
    for c in &r.checks {
        if c.status != Status::Pass {
            println!("  {}: {}: {}", if c.status == Status::Fail { "fail" } else { "warn" }, c.name, c.detail);
        }
    }
    if let Some(s) = &r.sheet {
        println!("  sheet {s}");
    }
}
