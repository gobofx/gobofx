// Template — effect. Reads `source`, writes `out` in two passes.
//
// The host prepends spec/prelude.wgsl to this file. It declares, and you
// must not redeclare:
//   gobofx_sampler              sampler            linear, clamp-to-edge
//   gobofx_globals.resolution   vec2f              output size in pixels
//   gobofx_globals.texel        vec2f              1.0 / resolution
//   gobofx_globals.time         f32                seconds since clip start
//   gobofx_globals.progress     f32                0..1 across the clip
//   gobofx_input0               texture_2d<f32>    this pass's first input
//   gobofx_input1               texture_2d<f32>    second input, or 1×1 transparent
//
// You declare: `Params` (one field per manifest param, same order, types
// from manifest.md), `Signals` (one f32 per manifest signal, same order),
// and one @fragment entry per pass. Colour is linear, premultiplied RGBA;
// values above 1.0 are legal (HDR).

// Pipeline-overridable constant, set per pass in the manifest `constants`.
override VIGNETTE: f32 = 0.0;

struct Params {
    amount: f32,   // float
    levels: i32,   // int
    invert: u32,   // bool   — 0 or 1
    blend: u32,    // choice — index into `options`
    tint: vec4f,   // color  — linear, premultiplied
    center: vec2f, // point  — uv, (0,0) top-left
}
@group(1) @binding(0) var<uniform> params: Params;

struct Signals {
    pulse: f32,    // 0..1, cc 1 on the plugin's MIDI 2.0 input
}
@group(1) @binding(1) var<uniform> gobofx_signals: Signals;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}

// Pass 0: source → graded. Tint by a blend mode, posterize, optionally invert.
@fragment
fn fs_grade(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    var rgb = unpremultiply(src);
    let tint = unpremultiply(params.tint);

    var blended: vec3f;
    switch params.blend {
        case 1u: { blended = rgb * tint; }                       // multiply
        case 2u: { blended = 1.0 - (1.0 - rgb) * (1.0 - tint); } // screen
        default: { blended = tint; }                              // normal
    }

    // A signal is just another number: here it pushes the amount up on the beat.
    let amount = clamp(params.amount + 0.5 * gobofx_signals.pulse, 0.0, 1.0);
    rgb = mix(rgb, blended, amount);

    let n = f32(max(params.levels, 2)) - 1.0;
    rgb = round(rgb * n) / n;

    if (params.invert == 1u) {
        rgb = 1.0 - rgb;
    }
    return vec4f(rgb * src.a, src.a); // back to premultiplied
}

// Pass 1: graded → out. Darken towards the edges, centred on the `point` param.
@fragment
fn fs_vignette(@location(0) uv: vec2f) -> @location(0) vec4f {
    let c = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    let falloff = 1.0 - VIGNETTE * smoothstep(0.3, 0.9, length(d));
    return vec4f(c.rgb * falloff, c.a); // scale colour only; alpha stays
}
