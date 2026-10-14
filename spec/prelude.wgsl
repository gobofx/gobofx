// GoboFX host prelude — v0.1 (draft)
// Prepended by the host to every plugin shader module. Plugins must not
// redeclare anything in this file.

struct WispGlobals {
    resolution: vec2f, // output size in pixels
    texel:      vec2f, // 1.0 / resolution
    time:       f32,   // seconds since clip start
    progress:   f32,   // transitions: 0..1 across the transition; effects: 0..1 across the clip
    _pad:       vec2f,
}

@group(0) @binding(0) var wisp_sampler: sampler;              // linear filter, clamp-to-edge
@group(0) @binding(1) var<uniform> wisp_globals: WispGlobals;
@group(0) @binding(2) var wisp_input0: texture_2d<f32>;      // effect: source · transition: from
@group(0) @binding(3) var wisp_input1: texture_2d<f32>;      // transition: to · effect: 1x1 transparent

// Group 1 is the plugin's: @binding(0) var<uniform> params: Params (manifest `params`)
// and @binding(1) var<uniform> wisp_signals: Signals (manifest `signals`), both declared
// by the plugin itself and only when it has them.

struct WispVertexOut {
    @builtin(position) position: vec4f,
    @location(0)       uv:       vec2f, // (0,0) = top-left
}

// Fullscreen triangle; the host draws 3 vertices with no vertex buffers.
@vertex
fn wisp_vs(@builtin(vertex_index) i: u32) -> WispVertexOut {
    let p = vec2f(f32((i << 1u) & 2u), f32(i & 2u));
    var out: WispVertexOut;
    out.position = vec4f(p * vec2f(2.0, -2.0) + vec2f(-1.0, 1.0), 0.0, 1.0);
    out.uv = p;
    return out;
}
