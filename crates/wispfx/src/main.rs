//! `wispfx` — test tool for WispFX plugins. Made for people and for agents:
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

use wispfx::manifest::{Kind, Plugin};
use wispfx::params;
use wispfx::render::{Globals, Host, Image};
use wispfx::validate::{self, Level};

#[derive(Parser)]
#[command(name = "wispfx", version, about = "Validate and render WispFX plugins headlessly.")]
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
}

#[derive(Args)]
struct RenderArgs {
    /// Plugin folder containing manifest.json
    dir: PathBuf,
    /// Input PNG. Effects take one (source); transitions take two (from, then to).
    #[arg(short, long = "input", required = true)]
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
                manifest: &'a wispfx::manifest::Manifest,
                report: &'a validate::Report,
            }
            println!("{}", serde_json::to_string_pretty(&Info { manifest: &plugin.manifest, report: &report })?);
            Ok(if report.ok { ExitCode::SUCCESS } else { ExitCode::from(1) })
        }
        Cmd::Render(args) => render(args),
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
    let first = inputs.get(match m.kind {
        Kind::Effect => "source",
        Kind::Transition => "from",
    });
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
