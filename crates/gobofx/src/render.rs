//! The host core: compile a plugin's passes into pipelines once, run them per frame.
//!
//! Everything here is target-agnostic and follows `spec/shader-abi.md` exactly:
//! working space linear premultiplied rgba16float, explicit bind group layouts so
//! unused bindings stay valid, a fullscreen triangle from the prelude's `gobofx_vs`.
//! The native CLI adds PNG in/out and a blocking readback behind the `cli` feature;
//! the browser host in `web.rs` adds a canvas surface and video import.

use std::collections::HashMap;

use anyhow::{anyhow, bail, Result};

use crate::assemble::assemble;
use crate::manifest::{Kind, Plugin};
use crate::params::{self, Layout, Value};
use crate::validate::module_uses_group1;

pub const WORKING_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Rgba16Float;

#[derive(Debug, Clone, Copy)]
pub struct Globals {
    pub time: f32,
    pub progress: f32,
}

/// One pass of a compiled plugin.
pub struct CompiledPass {
    pub pipeline: wgpu::RenderPipeline,
    pub uses_group1: bool,
    pub inputs: Vec<String>,
    pub output: String,
}

/// A plugin compiled against a [`Host`]: pipelines plus the layouts needed to fill group 1.
pub struct Compiled {
    pub id: String,
    pub kind: Kind,
    pub passes: Vec<CompiledPass>,
    pub params_layout: Layout,
    pub signals_layout: Layout,
    /// Bundled assets decoded and uploaded once: asset id → view (`spec/assets.md`).
    pub assets: HashMap<String, wgpu::TextureView>,
    /// `asset` params in manifest order: `(param id, index in the values list)`.
    pub asset_params: Vec<(String, usize)>,
}

/// A GPU device plus the fixed GoboFX bind group layouts.
pub struct Host {
    pub adapter_name: String,
    pub backend: String,
    pub adapter: wgpu::Adapter,
    pub device: wgpu::Device,
    pub queue: wgpu::Queue,
    pub sampler: wgpu::Sampler,
    pub bgl0: wgpu::BindGroupLayout,
    pub bgl1: wgpu::BindGroupLayout,
    /// 1×1 transparent, bound as `gobofx_input1` when a pass has one input.
    pub blank: wgpu::TextureView,
}

impl Host {
    /// Create a host on the given instance; `surface` lets the adapter be chosen for presentation.
    pub async fn new_async(instance: &wgpu::Instance, surface: Option<&wgpu::Surface<'_>>) -> Result<Host> {
        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::HighPerformance,
                force_fallback_adapter: false,
                compatible_surface: surface,
            })
            .await
            .map_err(|e| anyhow!("no GPU adapter: {e}"))?;
        let info = adapter.get_info();
        let (device, queue) = adapter
            .request_device(&wgpu::DeviceDescriptor {
                label: Some("gobofx"),
                required_features: wgpu::Features::empty(),
                required_limits: wgpu::Limits::default(),
                memory_hints: wgpu::MemoryHints::default(),
                trace: wgpu::Trace::Off,
            })
            .await
            .map_err(|e| anyhow!("device: {e}"))?;

        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("gobofx_sampler"),
            address_mode_u: wgpu::AddressMode::ClampToEdge,
            address_mode_v: wgpu::AddressMode::ClampToEdge,
            address_mode_w: wgpu::AddressMode::ClampToEdge,
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            mipmap_filter: wgpu::FilterMode::Nearest,
            ..Default::default()
        });

        let tex2d = |binding: u32| wgpu::BindGroupLayoutEntry {
            binding,
            visibility: wgpu::ShaderStages::FRAGMENT,
            ty: wgpu::BindingType::Texture {
                sample_type: wgpu::TextureSampleType::Float { filterable: true },
                view_dimension: wgpu::TextureViewDimension::D2,
                multisampled: false,
            },
            count: None,
        };
        let uniform = |binding: u32, visibility: wgpu::ShaderStages, min: Option<u64>| wgpu::BindGroupLayoutEntry {
            binding,
            visibility,
            ty: wgpu::BindingType::Buffer {
                ty: wgpu::BufferBindingType::Uniform,
                has_dynamic_offset: false,
                min_binding_size: min.and_then(wgpu::BufferSize::new),
            },
            count: None,
        };
        // Explicit layout with every prelude binding, so an unused one stays valid (shader-abi.md).
        let bgl0 = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("gobofx group 0"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                    count: None,
                },
                uniform(1, wgpu::ShaderStages::VERTEX_FRAGMENT, Some(32)),
                tex2d(2),
                tex2d(3),
            ],
        });
        // Group 1 always carries both plugin uniforms (params at 0, gobofx_signals at 1); a plugin
        // that declares only one still gets a valid, zero-filled buffer at the other binding.
        let bgl1 = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("gobofx group 1 (params, gobofx_signals)"),
            entries: &[uniform(0, wgpu::ShaderStages::FRAGMENT, None), uniform(1, wgpu::ShaderStages::FRAGMENT, None)],
        });

        let blank_tex = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("gobofx blank 1x1"),
            size: wgpu::Extent3d { width: 1, height: 1, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: WORKING_FORMAT,
            usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
            view_formats: &[],
        });
        queue.write_texture(
            blank_tex.as_image_copy(),
            &[0u8; 8],
            wgpu::TexelCopyBufferLayout { offset: 0, bytes_per_row: Some(8), rows_per_image: None },
            wgpu::Extent3d { width: 1, height: 1, depth_or_array_layers: 1 },
        );
        let blank = blank_tex.create_view(&Default::default());

        Ok(Host {
            adapter_name: info.name,
            backend: format!("{:?}", info.backend),
            adapter,
            device,
            queue,
            sampler,
            bgl0,
            bgl1,
            blank,
        })
    }

    /// Native, blocking constructor on the default instance.
    #[cfg(feature = "cli")]
    pub fn new() -> Result<Host> {
        let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor::default());
        pollster::block_on(Self::new_async(&instance, None))
    }

    /// A uniform buffer holding `bytes` (at least 16 bytes, zero-padded).
    pub fn uniform_buffer(&self, label: &str, bytes: &[u8]) -> wgpu::Buffer {
        let size = (bytes.len().max(16) as u64).div_ceil(16) * 16;
        let buf = self.device.create_buffer(&wgpu::BufferDescriptor {
            label: Some(label),
            size,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        if !bytes.is_empty() {
            self.queue.write_buffer(&buf, 0, bytes);
        }
        buf
    }

    /// The 32-byte `GobofxGlobals` block for an output of `width`×`height`.
    pub fn globals_buffer(&self, width: u32, height: u32, g: Globals) -> wgpu::Buffer {
        let data: [f32; 8] =
            [width as f32, height as f32, 1.0 / width as f32, 1.0 / height as f32, g.time, g.progress, 0.0, 0.0];
        self.uniform_buffer("gobofx_globals", bytemuck::cast_slice(&data))
    }

    /// A working-space render target.
    pub fn target(&self, width: u32, height: u32, label: &str, extra: wgpu::TextureUsages) -> wgpu::Texture {
        self.device.create_texture(&wgpu::TextureDescriptor {
            label: Some(label),
            size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: WORKING_FORMAT,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::TEXTURE_BINDING | extra,
            view_formats: &[],
        })
    }

    pub fn bind_group0(&self, globals: &wgpu::Buffer, in0: &wgpu::TextureView, in1: &wgpu::TextureView) -> wgpu::BindGroup {
        self.device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("gobofx group 0"),
            layout: &self.bgl0,
            entries: &[
                wgpu::BindGroupEntry { binding: 0, resource: wgpu::BindingResource::Sampler(&self.sampler) },
                wgpu::BindGroupEntry { binding: 1, resource: globals.as_entire_binding() },
                wgpu::BindGroupEntry { binding: 2, resource: wgpu::BindingResource::TextureView(in0) },
                wgpu::BindGroupEntry { binding: 3, resource: wgpu::BindingResource::TextureView(in1) },
            ],
        })
    }

    /// Build one pipeline from assembled WGSL, inside a validation error scope.
    pub async fn pipeline(
        &self,
        label: &str,
        wgsl: &str,
        fragment_entry: &str,
        constants: &[(&str, f64)],
        uses_group1: bool,
        format: wgpu::TextureFormat,
    ) -> Result<wgpu::RenderPipeline> {
        self.device.push_error_scope(wgpu::ErrorFilter::Validation);
        let module = self.device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some(label),
            source: wgpu::ShaderSource::Wgsl(wgsl.into()),
        });
        let bgls: Vec<&wgpu::BindGroupLayout> = if uses_group1 { vec![&self.bgl0, &self.bgl1] } else { vec![&self.bgl0] };
        let layout = self.device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some(label),
            bind_group_layouts: &bgls,
            push_constant_ranges: &[],
        });
        let pipeline = self.device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some(label),
            layout: Some(&layout),
            vertex: wgpu::VertexState {
                module: &module,
                entry_point: Some("gobofx_vs"),
                buffers: &[],
                compilation_options: wgpu::PipelineCompilationOptions::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: &module,
                entry_point: Some(fragment_entry),
                targets: &[Some(wgpu::ColorTargetState { format, blend: None, write_mask: wgpu::ColorWrites::ALL })],
                compilation_options: wgpu::PipelineCompilationOptions { constants, zero_initialize_workgroup_memory: false },
            }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview: None,
            cache: None,
        });
        if let Some(e) = self.device.pop_error_scope().await {
            bail!("{label}: {e}");
        }
        Ok(pipeline)
    }

    /// Compile every pass of a (validated) plugin.
    pub async fn compile(&self, plugin: &Plugin) -> Result<Compiled> {
        let m = &plugin.manifest;
        let mut passes = Vec::with_capacity(m.passes.len());
        for (i, pass) in m.passes.iter().enumerate() {
            let src = plugin
                .shaders
                .get(&pass.shader)
                .ok_or_else(|| anyhow!("pass {}: shader file \"{}\" missing", i, pass.shader))?;
            let assembled = assemble(src);
            let module_ir = naga::front::wgsl::parse_str(&assembled)
                .map_err(|e| anyhow!("pass {}: {}", i, e.emit_to_string(&assembled)))?;
            let uses_group1 = module_uses_group1(&module_ir);
            let constants: Vec<(&str, f64)> = pass.constants.iter().map(|(k, v)| (k.as_str(), v.as_f64())).collect();
            let pipeline = self
                .pipeline(&format!("{} pass {}", m.id, i), &assembled, &pass.entry, &constants, uses_group1, WORKING_FORMAT)
                .await
                .map_err(|e| anyhow!("pass {} ({}): {}", i, pass.shader, e))?;
            passes.push(CompiledPass { pipeline, uses_group1, inputs: pass.inputs.clone(), output: pass.output.clone() });
        }
        let mut assets = HashMap::new();
        for a in &m.assets {
            let bytes = plugin.assets.get(&a.file).ok_or_else(|| anyhow!("asset \"{}\": file \"{}\" missing", a.id, a.file))?;
            let view = match a.kind {
                crate::manifest::AssetKind::Lut3d => {
                    let lut = crate::cube::parse_cube(&String::from_utf8_lossy(bytes)).map_err(|e| anyhow!("asset \"{}\": {}", a.id, e))?;
                    self.upload_strip(&lut, &a.id)
                }
            };
            assets.insert(a.id.clone(), view);
        }
        let asset_params = m
            .params
            .iter()
            .enumerate()
            .filter(|(_, p)| p.ty == crate::manifest::ParamType::Asset)
            .map(|(i, p)| (p.id.clone(), i))
            .collect();
        Ok(Compiled {
            id: m.id.clone(),
            kind: m.kind,
            passes,
            params_layout: params::layout(m),
            signals_layout: params::signals_layout(m),
            assets,
            asset_params,
        })
    }

    /// Upload a `.cube` lattice as the strip texture the spec fixes (N tiles of N×N, rgba16float).
    pub fn upload_strip(&self, lut: &crate::cube::Lut3d, label: &str) -> wgpu::TextureView {
        let (w, h) = lut.strip_size();
        let tex = self.device.create_texture(&wgpu::TextureDescriptor {
            label: Some(label),
            size: wgpu::Extent3d { width: w, height: h, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: WORKING_FORMAT,
            usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
            view_formats: &[],
        });
        self.queue.write_texture(
            tex.as_image_copy(),
            &lut.strip_rgba16(),
            wgpu::TexelCopyBufferLayout { offset: 0, bytes_per_row: Some(w * 8), rows_per_image: None },
            wgpu::Extent3d { width: w, height: h, depth_or_array_layers: 1 },
        );
        tex.create_view(&Default::default())
    }

    /// Record a fullscreen draw of `pipeline` into `target`.
    pub fn draw(
        &self,
        encoder: &mut wgpu::CommandEncoder,
        label: &str,
        pipeline: &wgpu::RenderPipeline,
        target: &wgpu::TextureView,
        bg0: &wgpu::BindGroup,
        bg1: Option<&wgpu::BindGroup>,
    ) {
        let mut rp = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some(label),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view: target,
                resolve_target: None,
                ops: wgpu::Operations { load: wgpu::LoadOp::Clear(wgpu::Color::TRANSPARENT), store: wgpu::StoreOp::Store },
            })],
            depth_stencil_attachment: None,
            timestamp_writes: None,
            occlusion_query_set: None,
        });
        rp.set_pipeline(pipeline);
        rp.set_bind_group(0, bg0, &[]);
        if let Some(bg1) = bg1 {
            rp.set_bind_group(1, bg1, &[]);
        }
        rp.draw(0..3, 0..1);
    }

    /// Run every pass and return the `out` texture (working space, `extra` usage added).
    ///
    /// `inputs` is keyed by reserved name (`source`, or `from` and `to`), views in working space.
    #[allow(clippy::too_many_arguments)]
    pub fn run(
        &self,
        compiled: &Compiled,
        inputs: &HashMap<String, wgpu::TextureView>,
        size: (u32, u32),
        globals: Globals,
        values: &[Value],
        signal_values: &[f32],
        extra: wgpu::TextureUsages,
        encoder: &mut wgpu::CommandEncoder,
    ) -> Result<wgpu::Texture> {
        for name in compiled.kind.reserved_inputs() {
            if !inputs.contains_key(*name) {
                bail!("{:?} plugin needs input \"{}\"", compiled.kind, name);
            }
        }
        let (width, height) = size;
        if width == 0 || height == 0 {
            bail!("output size must be non-zero");
        }
        let globals_buf = self.globals_buffer(width, height, globals);
        let params_buf = self.uniform_buffer("params", &params::encode(&compiled.params_layout, values));
        let signals_buf = self.uniform_buffer("gobofx_signals", &params::encode_signals(&compiled.signals_layout, signal_values));
        let bg1 = self.device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("gobofx group 1"),
            layout: &self.bgl1,
            entries: &[
                wgpu::BindGroupEntry { binding: 0, resource: params_buf.as_entire_binding() },
                wgpu::BindGroupEntry { binding: 1, resource: signals_buf.as_entire_binding() },
            ],
        });

        let mut views: HashMap<String, wgpu::TextureView> = inputs.clone();
        // Bundled assets by id, then each `asset` param by its id: the chosen
        // bundled asset, a host-supplied view already in `inputs`, or blank.
        for (id, view) in &compiled.assets {
            views.entry(id.clone()).or_insert_with(|| view.clone());
        }
        for (pid, index) in &compiled.asset_params {
            if views.contains_key(pid) {
                continue;
            }
            let chosen = match values.get(*index) {
                Some(Value::Asset(Some(id))) => compiled.assets.get(id).cloned(),
                _ => None,
            };
            views.insert(pid.clone(), chosen.unwrap_or_else(|| self.blank.clone()));
        }
        let mut out = None;
        for (i, pass) in compiled.passes.iter().enumerate() {
            let in0 = match pass.inputs.first() {
                Some(n) => views.get(n).ok_or_else(|| anyhow!("pass {}: input \"{}\" is not available", i, n))?,
                None => &self.blank,
            };
            let in1 = match pass.inputs.get(1) {
                Some(n) => views.get(n).ok_or_else(|| anyhow!("pass {}: input \"{}\" is not available", i, n))?,
                None => &self.blank,
            };
            let bg0 = self.bind_group0(&globals_buf, in0, in1);
            let is_out = pass.output == "out";
            let target = self.target(width, height, &pass.output, if is_out { extra } else { wgpu::TextureUsages::empty() });
            let view = target.create_view(&Default::default());
            self.draw(encoder, &format!("pass {} → {}", i, pass.output), &pass.pipeline, &view, &bg0, pass.uses_group1.then_some(&bg1));
            if is_out {
                out = Some(target);
            } else {
                views.insert(pass.output.clone(), view);
            }
        }
        out.ok_or_else(|| anyhow!("no pass wrote \"out\""))
    }
}

// ── Native image path (CLI) ───────────────────────────────────────────

#[cfg(feature = "cli")]
pub use native::{Frame, Image};

#[cfg(feature = "cli")]
mod native {
    use std::collections::{BTreeMap, HashMap};

    use anyhow::{anyhow, Context, Result};
    use half::f16;

    use super::{Compiled, Globals, Host, WORKING_FORMAT};
    use crate::params::Value;

    /// An 8-bit sRGB image with straight alpha — what PNG stores.
    #[derive(Debug, Clone)]
    pub struct Image {
        pub width: u32,
        pub height: u32,
        pub rgba8: Vec<u8>,
    }

    impl Image {
        pub fn load_png(path: &std::path::Path) -> Result<Image> {
            let img = image::open(path).with_context(|| format!("reading {}", path.display()))?.to_rgba8();
            Ok(Image { width: img.width(), height: img.height(), rgba8: img.into_raw() })
        }

        pub fn save_png(&self, path: &std::path::Path) -> Result<()> {
            image::save_buffer(path, &self.rgba8, self.width, self.height, image::ColorType::Rgba8)
                .with_context(|| format!("writing {}", path.display()))
        }
    }

    fn srgb_to_linear(c: f32) -> f32 {
        if c <= 0.04045 {
            c / 12.92
        } else {
            ((c + 0.055) / 1.055).powf(2.4)
        }
    }

    fn linear_to_srgb(c: f32) -> f32 {
        let c = c.clamp(0.0, 1.0);
        if c <= 0.0031308 {
            c * 12.92
        } else {
            1.055 * c.powf(1.0 / 2.4) - 0.055
        }
    }

    /// sRGB straight alpha u8 → linear premultiplied f16 bytes.
    fn to_working_space(img: &Image) -> Vec<u8> {
        let mut out = Vec::with_capacity(img.rgba8.len() * 2);
        for px in img.rgba8.chunks_exact(4) {
            let a = px[3] as f32 / 255.0;
            for c in &px[..3] {
                let l = srgb_to_linear(*c as f32 / 255.0) * a;
                out.extend_from_slice(&f16::from_f32(l).to_bits().to_le_bytes());
            }
            out.extend_from_slice(&f16::from_f32(a).to_bits().to_le_bytes());
        }
        out
    }


    impl Host {
        fn upload(&self, img: &Image, label: &str) -> wgpu::Texture {
            let tex = self.device.create_texture(&wgpu::TextureDescriptor {
                label: Some(label),
                size: wgpu::Extent3d { width: img.width, height: img.height, depth_or_array_layers: 1 },
                mip_level_count: 1,
                sample_count: 1,
                dimension: wgpu::TextureDimension::D2,
                format: WORKING_FORMAT,
                usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
                view_formats: &[],
            });
            self.queue.write_texture(
                tex.as_image_copy(),
                &to_working_space(img),
                wgpu::TexelCopyBufferLayout { offset: 0, bytes_per_row: Some(img.width * 8), rows_per_image: None },
                wgpu::Extent3d { width: img.width, height: img.height, depth_or_array_layers: 1 },
            );
            tex
        }

        /// Run the plugin on PNG-style inputs and read the result back as a PNG-style image.
        pub fn render_image(
            &self,
            compiled: &Compiled,
            inputs: &BTreeMap<String, Image>,
            size: (u32, u32),
            globals: Globals,
            values: &[Value],
            signal_values: &[f32],
        ) -> Result<Image> {
            Ok(self.render_frame(compiled, inputs, size, globals, values, signal_values)?.to_image())
        }

        /// Run the plugin and read the working-space result back unconverted:
        /// linear, premultiplied f32 (from the rgba16float target). This is what
        /// `verify` inspects, because the PNG conversion clamps and would hide
        /// NaN, negative or out-of-range values.
        pub fn render_frame(
            &self,
            compiled: &Compiled,
            inputs: &BTreeMap<String, Image>,
            size: (u32, u32),
            globals: Globals,
            values: &[Value],
            signal_values: &[f32],
        ) -> Result<Frame> {
            let textures: Vec<(String, wgpu::Texture)> = inputs.iter().map(|(n, img)| (n.clone(), self.upload(img, n))).collect();
            let views: HashMap<String, wgpu::TextureView> =
                textures.iter().map(|(n, t)| (n.clone(), t.create_view(&Default::default()))).collect();

            let mut encoder = self.device.create_command_encoder(&wgpu::CommandEncoderDescriptor { label: Some("gobofx") });
            let out = self.run(compiled, &views, size, globals, values, signal_values, wgpu::TextureUsages::COPY_SRC, &mut encoder)?;

            let (width, height) = size;
            let unpadded = width * 8;
            let padded = unpadded.div_ceil(256) * 256;
            let readback = self.device.create_buffer(&wgpu::BufferDescriptor {
                label: Some("readback"),
                size: (padded * height) as u64,
                usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
                mapped_at_creation: false,
            });
            encoder.copy_texture_to_buffer(
                out.as_image_copy(),
                wgpu::TexelCopyBufferInfo {
                    buffer: &readback,
                    layout: wgpu::TexelCopyBufferLayout { offset: 0, bytes_per_row: Some(padded), rows_per_image: None },
                },
                wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
            );
            self.queue.submit([encoder.finish()]);

            let slice = readback.slice(..);
            let (tx, rx) = std::sync::mpsc::channel();
            slice.map_async(wgpu::MapMode::Read, move |r| {
                let _ = tx.send(r);
            });
            self.device.poll(wgpu::PollType::wait()).map_err(|e| anyhow!("poll: {e:?}"))?;
            rx.recv().context("map_async never completed")?.map_err(|e| anyhow!("map: {e}"))?;
            let data = slice.get_mapped_range();
            let mut tight = Vec::with_capacity((unpadded * height) as usize);
            for row in 0..height as usize {
                let start = row * padded as usize;
                tight.extend_from_slice(&data[start..start + unpadded as usize]);
            }
            drop(data);
            readback.unmap();
            let rgba = tight
                .chunks_exact(2)
                .map(|b| f16::from_bits(u16::from_le_bytes([b[0], b[1]])).to_f32())
                .collect();
            Ok(Frame { width, height, rgba })
        }
    }

    /// A rendered frame in the working space: linear, premultiplied, four f32 per pixel.
    #[derive(Debug, Clone)]
    pub struct Frame {
        pub width: u32,
        pub height: u32,
        pub rgba: Vec<f32>,
    }

    impl Frame {
        /// The frame as PNG-style sRGB straight-alpha 8-bit (clamped).
        pub fn to_image(&self) -> Image {
            let mut rgba8 = Vec::with_capacity(self.rgba.len());
            for px in self.rgba.chunks_exact(4) {
                let a = px[3].clamp(0.0, 1.0);
                for c in &px[..3] {
                    let straight = if a > 0.0 { c / a } else { 0.0 };
                    rgba8.push((linear_to_srgb(straight) * 255.0 + 0.5) as u8);
                }
                rgba8.push((a * 255.0 + 0.5) as u8);
            }
            Image { width: self.width, height: self.height, rgba8 }
        }

        /// An input image in the same working space, for comparing against a render.
        pub fn from_image(img: &Image) -> Frame {
            let rgba = img
                .rgba8
                .chunks_exact(4)
                .flat_map(|px| {
                    let a = px[3] as f32 / 255.0;
                    [
                        srgb_to_linear(px[0] as f32 / 255.0) * a,
                        srgb_to_linear(px[1] as f32 / 255.0) * a,
                        srgb_to_linear(px[2] as f32 / 255.0) * a,
                        a,
                    ]
                })
                .collect();
            Frame { width: img.width, height: img.height, rgba }
        }
    }
}
