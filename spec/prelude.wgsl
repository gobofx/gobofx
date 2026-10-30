// GoboFX host prelude — v0.1 (draft)
// Prepended by the host to every plugin shader module. Plugins must not
// redeclare anything in this file.

struct GobofxGlobals {
    resolution: vec2f, // output size in pixels
    texel:      vec2f, // 1.0 / resolution
    time:       f32,   // seconds since clip start
    progress:   f32,   // transitions: 0..1 across the transition; effects: 0..1 across the clip
    _pad:       vec2f,
}

@group(0) @binding(0) var gobofx_sampler: sampler;              // linear filter, clamp-to-edge
@group(0) @binding(1) var<uniform> gobofx_globals: GobofxGlobals;
@group(0) @binding(2) var gobofx_input0: texture_2d<f32>;      // effect: source · transition: from
@group(0) @binding(3) var gobofx_input1: texture_2d<f32>;      // transition: to · effect: 1x1 transparent

// Group 1 is the plugin's: @binding(0) var<uniform> params: Params (manifest `params`)
// and @binding(1) var<uniform> gobofx_signals: Signals (manifest `signals`), both declared
// by the plugin itself and only when it has them.

// v0.2 draft (grading.md): read a baked `curve` strip at x in 0..1. Samples
// texel centres, so x = 0 and x = 1 land exactly on the first and last baked
// samples. Periodic (hue) curves pass fract(x).
fn gobofx_curve(strip: texture_2d<f32>, x: f32) -> vec4f {
    let n = f32(textureDimensions(strip).x);
    let u = clamp(x, 0.0, 1.0) * ((n - 1.0) / n) + 0.5 / n;
    return textureSampleLevel(strip, gobofx_sampler, vec2f(u, 0.5), 0.0);
}

struct GobofxVertexOut {
    @builtin(position) position: vec4f,
    @location(0)       uv:       vec2f, // (0,0) = top-left
}

// Fullscreen triangle; the host draws 3 vertices with no vertex buffers.
@vertex
fn gobofx_vs(@builtin(vertex_index) i: u32) -> GobofxVertexOut {
    let p = vec2f(f32((i << 1u) & 2u), f32(i & 2u));
    var out: GobofxVertexOut;
    out.position = vec4f(p * vec2f(2.0, -2.0) + vec2f(-1.0, 1.0), 0.0, 1.0);
    out.uv = p;
    return out;
}
