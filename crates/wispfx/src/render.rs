//! A headless wgpu host: runs a plugin's passes exactly as `spec/shader-abi.md` says and
//! reads the final `out` image back. Inputs are PNGs (sRGB, straight alpha) and are converted
//! to the working space (linear, premultiplied, rgba16float) on upload; the output is
//! converted back for the PNG.

use std::collections::{BTreeMap, HashMap};

use anyhow::{anyhow, bail, Context, Result};
use half::f16;

use crate::assemble::assemble;
use crate::manifest::Plugin;
use crate::params::{self, Value};
use crate::validate::module_uses_group1;

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

#[derive(Debug, Clone, Copy)]
pub struct Globals {
    pub time: f32,
    pub progress: f32,
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

/// linear premultiplied f16 bytes → sRGB straight alpha u8.
fn from_working_space(bytes: &[u8], width: u32, height: u32) -> Image {
    let mut rgba8 = Vec::with_capacity((width * height * 4) as usize);
    for px in bytes.chunks_exact(8).take((width * height) as usize) {
        let f = |i: usize| f16::from_bits(u16::from_le_bytes([px[i * 2], px[i * 2 + 1]])).to_f32();
        let a = f(3).clamp(0.0, 1.0);
        for i in 0..3 {
            let straight = if a > 0.0 { f(i) / a } else { 0.0 };
            rgba8.push((linear_to_srgb(straight) * 255.0 + 0.5) as u8);
        }
        rgba8.push((a * 255.0 + 0.5) as u8);
    }
    Image { width, height, rgba8 }
}

const WORKING_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Rgba16Float;

/// A GPU device ready to run plugins.
pub struct Host {
    pub adapter_name: String,
    pub backend: String,
    device: wgpu::Device,
    queue: wgpu::Queue,
    sampler: wgpu::Sampler,
    bgl0: wgpu::BindGroupLayout,
    bgl1: wgpu::BindGroupLayout,
    blank: wgpu::TextureView,
}

impl Host {
    pub fn new() -> Result<Host> {
        pollster::block_on(Self::new_async())
    }

    async fn new_async() -> Result<Host> {
        let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor::default());
        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::HighPerformance,
                force_fallback_adapter: false,
                compatible_surface: None,
            })
            .await
            .map_err(|e| anyhow!("no GPU adapter: {e}"))?;
        let info = adapter.get_info();
        let (device, queue) = adapter
            .request_device(&wgpu::DeviceDescriptor {
                label: Some("wispfx"),
                required_features: wgpu::Features::empty(),
                required_limits: wgpu::Limits::default(),
                memory_hints: wgpu::MemoryHints::default(),
                trace: wgpu::Trace::Off,
            })
            .await
            .map_err(|e| anyhow!("device: {e}"))?;

        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("wisp_sampler"),
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
        // Explicit layout with every prelude binding, so an unused one stays valid (shader-abi.md).
        let bgl0 = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("wisp group 0"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::VERTEX_FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: wgpu::BufferSize::new(32),
                    },
                    count: None,
                },
                tex2d(2),
                tex2d(3),
            ],
        });
        let uniform = |binding: u32| wgpu::BindGroupLayoutEntry {
            binding,
            visibility: wgpu::ShaderStages::FRAGMENT,
            ty: wgpu::BindingType::Buffer {
                ty: wgpu::BufferBindingType::Uniform,
                has_dynamic_offset: false,
                min_binding_size: None,
            },
            count: None,
        };
        // Group 1 always carries both plugin uniforms (params at 0, wisp_signals at 1); a plugin
        // that declares only one still gets a valid, zero-filled buffer at the other binding.
        let bgl1 = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("wisp group 1 (params, wisp_signals)"),
            entries: &[uniform(0), uniform(1)],
        });

        let blank_tex = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("wisp blank 1x1"),
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
            device,
            queue,
            sampler,
            bgl0,
            bgl1,
            blank,
        })
    }

    /// A uniform buffer holding `bytes` (at least 16 bytes, zero-padded).
    fn uniform_buffer(&self, label: &str, bytes: &[u8]) -> wgpu::Buffer {
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

    fn target(&self, width: u32, height: u32, label: &str) -> wgpu::Texture {
        self.device.create_texture(&wgpu::TextureDescriptor {
            label: Some(label),
            size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: WORKING_FORMAT,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT
                | wgpu::TextureUsages::TEXTURE_BINDING
                | wgpu::TextureUsages::COPY_SRC,
            view_formats: &[],
        })
    }

    /// Run every pass of `plugin` and return the final `out` image.
    ///
    /// `inputs` is keyed by reserved name (`source`, or `from` and `to`). `size` is the output size.
    pub fn render(
        &self,
        plugin: &Plugin,
        inputs: &BTreeMap<String, Image>,
        size: (u32, u32),
        globals: Globals,
        values: &[Value],
        signal_values: &[f32],
    ) -> Result<Image> {
        let m = &plugin.manifest;
        for name in m.kind.reserved_inputs() {
            if !inputs.contains_key(*name) {
                bail!("{:?} plugin needs input \"{}\"", m.kind, name);
            }
        }
        let (width, height) = size;
        if width == 0 || height == 0 {
            bail!("output size must be non-zero");
        }

        // Uniforms.
        let globals_bytes: [f32; 8] = [
            width as f32,
            height as f32,
            1.0 / width as f32,
            1.0 / height as f32,
            globals.time,
            globals.progress,
            0.0,
            0.0,
        ];
        let globals_buf = self.device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("wisp_globals"),
            size: 32,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        self.queue.write_buffer(&globals_buf, 0, bytemuck::cast_slice(&globals_bytes));

        let layout = params::layout(m);
        let params_buf = self.uniform_buffer("params", &params::encode(&layout, values));
        let signals_layout = params::signals_layout(m);
        let signals_buf = self.uniform_buffer("wisp_signals", &params::encode_signals(&signals_layout, signal_values));

        // Images by name: reserved inputs first, pass outputs as they are produced.
        let mut images: HashMap<String, wgpu::Texture> = HashMap::new();
        for (name, img) in inputs {
            images.insert(name.clone(), self.upload(img, name));
        }

        let mut encoder = self.device.create_command_encoder(&wgpu::CommandEncoderDescriptor { label: Some("wispfx") });
        let mut out_tex = None;

        for (i, pass) in m.passes.iter().enumerate() {
            let src = plugin
                .shaders
                .get(&pass.shader)
                .ok_or_else(|| anyhow!("pass {}: shader file \"{}\" missing", i, pass.shader))?;
            let assembled = assemble(src);
            let module_ir = naga::front::wgsl::parse_str(&assembled)
                .map_err(|e| anyhow!("pass {}: {}", i, e.emit_to_string(&assembled)))?;
            let uses_group1 = module_uses_group1(&module_ir);

            self.device.push_error_scope(wgpu::ErrorFilter::Validation);
            let module = self.device.create_shader_module(wgpu::ShaderModuleDescriptor {
                label: Some(&format!("{} pass {}", m.id, i)),
                source: wgpu::ShaderSource::Wgsl(assembled.as_str().into()),
            });
            let constants: Vec<(&str, f64)> = pass.constants.iter().map(|(k, v)| (k.as_str(), v.as_f64())).collect();
            let bgls: Vec<&wgpu::BindGroupLayout> =
                if uses_group1 { vec![&self.bgl0, &self.bgl1] } else { vec![&self.bgl0] };
            let pipeline_layout = self.device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
                label: None,
                bind_group_layouts: &bgls,
                push_constant_ranges: &[],
            });
            let pipeline = self.device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
                label: Some(&format!("{} pass {}", m.id, i)),
                layout: Some(&pipeline_layout),
                vertex: wgpu::VertexState {
                    module: &module,
                    entry_point: Some("wisp_vs"),
                    buffers: &[],
                    compilation_options: wgpu::PipelineCompilationOptions::default(),
                },
                fragment: Some(wgpu::FragmentState {
                    module: &module,
                    entry_point: Some(&pass.entry),
                    targets: &[Some(wgpu::ColorTargetState {
                        format: WORKING_FORMAT,
                        blend: None,
                        write_mask: wgpu::ColorWrites::ALL,
                    })],
                    compilation_options: wgpu::PipelineCompilationOptions {
                        constants: &constants,
                        zero_initialize_workgroup_memory: false,
                    },
                }),
                primitive: wgpu::PrimitiveState::default(),
                depth_stencil: None,
                multisample: wgpu::MultisampleState::default(),
                multiview: None,
                cache: None,
            });
            if let Some(e) = pollster::block_on(self.device.pop_error_scope()) {
                bail!("pass {} ({}): {}", i, pass.shader, e);
            }

            let view = |name: &str| -> Result<wgpu::TextureView> {
                images
                    .get(name)
                    .map(|t| t.create_view(&Default::default()))
                    .ok_or_else(|| anyhow!("pass {}: input \"{}\" is not available", i, name))
            };
            let in0 = view(&pass.inputs[0])?;
            let in1 = match pass.inputs.get(1) {
                Some(n) => view(n)?,
                None => self.blank.clone(),
            };
            let bg0 = self.device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("wisp group 0"),
                layout: &self.bgl0,
                entries: &[
                    wgpu::BindGroupEntry { binding: 0, resource: wgpu::BindingResource::Sampler(&self.sampler) },
                    wgpu::BindGroupEntry { binding: 1, resource: globals_buf.as_entire_binding() },
                    wgpu::BindGroupEntry { binding: 2, resource: wgpu::BindingResource::TextureView(&in0) },
                    wgpu::BindGroupEntry { binding: 3, resource: wgpu::BindingResource::TextureView(&in1) },
                ],
            });
            let bg1 = uses_group1.then(|| {
                self.device.create_bind_group(&wgpu::BindGroupDescriptor {
                    label: Some("wisp group 1"),
                    layout: &self.bgl1,
                    entries: &[
                        wgpu::BindGroupEntry { binding: 0, resource: params_buf.as_entire_binding() },
                        wgpu::BindGroupEntry { binding: 1, resource: signals_buf.as_entire_binding() },
                    ],
                })
            });

            let target = self.target(width, height, &pass.output);
            let target_view = target.create_view(&Default::default());
            {
                let mut rp = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                    label: Some(&format!("pass {} → {}", i, pass.output)),
                    color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                        view: &target_view,
                        resolve_target: None,
                        ops: wgpu::Operations {
                            load: wgpu::LoadOp::Clear(wgpu::Color::TRANSPARENT),
                            store: wgpu::StoreOp::Store,
                        },
                    })],
                    depth_stencil_attachment: None,
                    timestamp_writes: None,
                    occlusion_query_set: None,
                });
                rp.set_pipeline(&pipeline);
                rp.set_bind_group(0, &bg0, &[]);
                if let Some(bg1) = &bg1 {
                    rp.set_bind_group(1, bg1, &[]);
                }
                rp.draw(0..3, 0..1);
            }
            if pass.output == "out" {
                out_tex = Some(target);
            } else {
                images.insert(pass.output.clone(), target);
            }
        }

        let out_tex = out_tex.ok_or_else(|| anyhow!("no pass wrote \"out\""))?;

        // Read back: rows padded to 256 bytes.
        let unpadded = width * 8;
        let padded = unpadded.div_ceil(256) * 256;
        let readback = self.device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("readback"),
            size: (padded * height) as u64,
            usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
            mapped_at_creation: false,
        });
        encoder.copy_texture_to_buffer(
            out_tex.as_image_copy(),
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
        Ok(from_working_space(&tight, width, height))
    }
}
