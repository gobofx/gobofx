//! Browser host: the same core as the CLI, presented through wasm-bindgen.
//!
//! The page owns the `<canvas>`, the `<video>` elements and the signal values
//! (audio follower, Web MIDI, sliders). This module owns everything GPU:
//! validation, compilation, video import into the working space, the passes,
//! and the blit to the canvas. One implementation for native and web.

use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;

use anyhow::{anyhow, Result};
use js_sys::Promise;
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::future_to_promise;
use web_sys::{HtmlCanvasElement, HtmlVideoElement};

use crate::assemble::assemble;
use crate::manifest::{Manifest, Plugin};
use crate::params;
use crate::render::{Compiled, Globals, Host, WORKING_FORMAT};
use crate::validate;

/// Imports a video frame (sampled from an sRGB-encoded texture, so linear here) into premultiplied working space.
const IMPORT_BODY: &str = r#"
@fragment
fn fs_import(@location(0) uv: vec2f) -> @location(0) vec4f {
    let c = textureSampleLevel(wisp_input0, wisp_sampler, uv, 0.0);
    return vec4f(c.rgb * c.a, c.a);
}
"#;

/// Blits working space to the canvas: unpremultiply, encode sRGB, premultiply again (canvas alphaMode premultiplied).
const BLIT_BODY: &str = r#"
fn srgb(c: vec3f) -> vec3f {
    let lo = c * 12.92;
    let hi = 1.055 * pow(c, vec3f(1.0 / 2.4)) - 0.055;
    return select(hi, lo, c <= vec3f(0.0031308));
}
@fragment
fn fs_blit(@location(0) uv: vec2f) -> @location(0) vec4f {
    let p = textureSampleLevel(wisp_input0, wisp_sampler, uv, 0.0);
    let a = clamp(p.a, 0.0, 1.0);
    let straight = select(vec3f(0.0), clamp(p.rgb / max(a, 1e-6), vec3f(0.0), vec3f(1.0)), a > 0.0);
    return vec4f(srgb(straight) * a, a);
}
"#;

struct Source {
    srgb: wgpu::Texture,
    linear_view: wgpu::TextureView,
    width: u32,
    height: u32,
}

struct Inner {
    host: Host,
    surface: wgpu::Surface<'static>,
    config: wgpu::SurfaceConfiguration,
    import: wgpu::RenderPipeline,
    blit: wgpu::RenderPipeline,
    plugin: Option<Plugin>,
    compiled: Option<Compiled>,
    sources: HashMap<String, Source>,
}

fn js(e: impl std::fmt::Display) -> JsValue {
    JsValue::from_str(&e.to_string())
}

/// Create a host that presents into `canvas`. Resolves once the GPU device is ready.
#[wasm_bindgen]
pub async fn create_host(canvas: HtmlCanvasElement) -> Result<WebHost, JsValue> {
    std::panic::set_hook(Box::new(|info| {
        web_sys::console::error_1(&format!("wispfx panic: {info}").into());
    }));
    let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor {
        backends: wgpu::Backends::BROWSER_WEBGPU,
        ..Default::default()
    });
    let surface = instance.create_surface(wgpu::SurfaceTarget::Canvas(canvas.clone())).map_err(js)?;
    let host = Host::new_async(&instance, Some(&surface)).await.map_err(js)?;

    let caps = surface.get_capabilities(&host.adapter);
    let format = caps.formats.iter().copied().find(|f| !f.is_srgb()).unwrap_or(caps.formats[0]);
    let alpha_mode = if caps.alpha_modes.contains(&wgpu::CompositeAlphaMode::PreMultiplied) {
        wgpu::CompositeAlphaMode::PreMultiplied
    } else {
        caps.alpha_modes[0]
    };
    let config = wgpu::SurfaceConfiguration {
        usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
        format,
        width: canvas.width().max(1),
        height: canvas.height().max(1),
        present_mode: wgpu::PresentMode::Fifo,
        alpha_mode,
        view_formats: vec![],
        desired_maximum_frame_latency: 2,
    };
    surface.configure(&host.device, &config);

    let import = host.pipeline("import", &assemble(IMPORT_BODY), "fs_import", &[], false, WORKING_FORMAT).await.map_err(js)?;
    let blit = host.pipeline("blit", &assemble(BLIT_BODY), "fs_blit", &[], false, format).await.map_err(js)?;

    Ok(WebHost {
        inner: Rc::new(RefCell::new(Inner {
            host,
            surface,
            config,
            import,
            blit,
            plugin: None,
            compiled: None,
            sources: HashMap::new(),
        })),
    })
}

#[wasm_bindgen]
pub struct WebHost {
    inner: Rc<RefCell<Inner>>,
}

#[wasm_bindgen]
impl WebHost {
    /// GPU adapter name, for display.
    pub fn adapter_name(&self) -> String {
        self.inner.borrow().host.adapter_name.clone()
    }

    /// Validate and compile a plugin. `shaders` is an object `{ "shader.wgsl": "<source>" }`.
    /// Resolves to the validation report as a JSON string (see `validate::Report`); the plugin
    /// is installed only when the report is ok.
    pub fn load_plugin(&self, manifest_json: String, shaders: JsValue) -> Promise {
        let inner = self.inner.clone();
        future_to_promise(async move {
            let manifest: Manifest = serde_json::from_str(&manifest_json).map_err(js)?;
            let mut files = std::collections::BTreeMap::new();
            if shaders.is_object() {
                for entry in js_sys::Object::entries(&js_sys::Object::from(shaders)).iter() {
                    let pair = js_sys::Array::from(&entry);
                    let k = pair.get(0).as_string().unwrap_or_default();
                    let v = pair.get(1).as_string().unwrap_or_default();
                    files.insert(k, v);
                }
            }
            let plugin = Plugin { dir: std::path::PathBuf::from("."), manifest, shaders: files };
            let report = validate::validate(&plugin);
            let json = serde_json::to_string(&report).map_err(js)?;
            if report.ok {
                let compiled = {
                    let i = inner.borrow();
                    i.host.compile(&plugin).await.map_err(js)?
                };
                let mut i = inner.borrow_mut();
                i.compiled = Some(compiled);
                i.plugin = Some(plugin);
            }
            Ok(JsValue::from_str(&json))
        })
    }

    /// Copy the video's current frame into the named input (`source`, `from` or `to`).
    pub fn set_video(&self, name: String, video: &HtmlVideoElement) -> Result<(), JsValue> {
        let mut i = self.inner.borrow_mut();
        let (w, h) = (video.video_width(), video.video_height());
        if w == 0 || h == 0 {
            return Ok(()); // not ready yet
        }
        let needs_new = i.sources.get(&name).is_none_or(|s| s.width != w || s.height != h);
        if needs_new {
            let srgb = i.host.device.create_texture(&wgpu::TextureDescriptor {
                label: Some("video srgb"),
                size: wgpu::Extent3d { width: w, height: h, depth_or_array_layers: 1 },
                mip_level_count: 1,
                sample_count: 1,
                dimension: wgpu::TextureDimension::D2,
                format: wgpu::TextureFormat::Rgba8UnormSrgb,
                usage: wgpu::TextureUsages::COPY_DST | wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::RENDER_ATTACHMENT,
                view_formats: &[],
            });
            let linear = i.host.target(w, h, &name, wgpu::TextureUsages::empty());
            let linear_view = linear.create_view(&Default::default());
            i.sources.insert(name.clone(), Source { srgb, linear_view, width: w, height: h });
        }
        let Inner { host, import, sources, .. } = &mut *i;
        let src = sources.get(&name).expect("inserted above");
        host.queue.copy_external_image_to_texture(
            &wgpu::CopyExternalImageSourceInfo {
                source: wgpu::ExternalImageSource::HTMLVideoElement(video.clone()),
                origin: wgpu::Origin2d::ZERO,
                flip_y: false,
            },
            wgpu::CopyExternalImageDestInfo {
                texture: &src.srgb,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                aspect: wgpu::TextureAspect::All,
                color_space: wgpu::PredefinedColorSpace::Srgb,
                premultiplied_alpha: true,
            },
            wgpu::Extent3d { width: w, height: h, depth_or_array_layers: 1 },
        );
        // sRGB texture → linear premultiplied working space.
        let globals = host.globals_buffer(w, h, Globals { time: 0.0, progress: 0.0 });
        let srgb_view = src.srgb.create_view(&Default::default());
        let bg0 = host.bind_group0(&globals, &srgb_view, &host.blank);
        let mut encoder = host.device.create_command_encoder(&wgpu::CommandEncoderDescriptor { label: Some("import") });
        host.draw(&mut encoder, "import", import, &src.linear_view, &bg0, None);
        host.queue.submit([encoder.finish()]);
        Ok(())
    }

    /// Resize the canvas surface.
    pub fn resize(&self, width: u32, height: u32) {
        let mut i = self.inner.borrow_mut();
        i.config.width = width.max(1);
        i.config.height = height.max(1);
        let Inner { host, surface, config, .. } = &*i;
        surface.configure(&host.device, config);
    }

    /// Render one frame to the canvas. `params_json` and `signals_json` are objects keyed by id;
    /// missing keys use manifest defaults.
    pub fn render(&self, time: f32, progress: f32, params_json: String, signals_json: String) -> Result<(), JsValue> {
        self.render_inner(time, progress, &params_json, &signals_json).map_err(js)
    }

    fn render_inner(&self, time: f32, progress: f32, params_json: &str, signals_json: &str) -> Result<()> {
        let i = self.inner.borrow();
        let (plugin, compiled) = match (&i.plugin, &i.compiled) {
            (Some(p), Some(c)) => (p, c),
            _ => return Err(anyhow!("no plugin loaded")),
        };
        let m = &plugin.manifest;
        let pv: serde_json::Value = serde_json::from_str(params_json).unwrap_or(serde_json::Value::Null);
        let sv: serde_json::Value = serde_json::from_str(signals_json).unwrap_or(serde_json::Value::Null);
        let values: Vec<params::Value> =
            m.params.iter().map(|p| params::value_from_json(p, pv.get(&p.id))).collect::<Result<_>>()?;
        let signal_values: Vec<f32> = m
            .signals
            .iter()
            .map(|s| sv.get(&s.id).and_then(|v| v.as_f64()).unwrap_or(s.default.unwrap_or(0.0)).clamp(0.0, 1.0) as f32)
            .collect();

        let mut inputs = HashMap::new();
        for name in m.kind.reserved_inputs() {
            let src = i.sources.get(*name).ok_or_else(|| anyhow!("input \"{}\" has no video yet", name))?;
            inputs.insert(name.to_string(), src.linear_view.clone());
        }
        let size = (i.config.width, i.config.height);
        let host = &i.host;
        let mut encoder = host.device.create_command_encoder(&wgpu::CommandEncoderDescriptor { label: Some("wispfx frame") });
        let out = host.run(compiled, &inputs, size, Globals { time, progress }, &values, &signal_values, wgpu::TextureUsages::empty(), &mut encoder)?;

        let frame = i.surface.get_current_texture().map_err(|e| anyhow!("surface: {e}"))?;
        let frame_view = frame.texture.create_view(&Default::default());
        let out_view = out.create_view(&Default::default());
        let globals = host.globals_buffer(size.0, size.1, Globals { time, progress });
        let bg0 = host.bind_group0(&globals, &out_view, &host.blank);
        host.draw(&mut encoder, "blit", &i.blit, &frame_view, &bg0, None);
        host.queue.submit([encoder.finish()]);
        frame.present();
        Ok(())
    }
}
