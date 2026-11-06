// Underwater — the wobble of looking through moving water: two layers of
// slow, crossing sine waves displace the picture in both axes and drift with
// time, and a faint brightness ripple follows the displacement like a
// caustic. Amount 0 is a no-op. Pixels pulled from outside the frame repeat
// the edge.
const TAU: f32 = 6.28318530718;
// Displacement at Amount 1, in frame heights.
const MAX_SHIFT: f32 = 0.06;

struct Params {
    scale: f32,  // float — size of the waves in frame heights
    amount: f32, // float — 0 is a no-op, 1 the full wobble
    speed: f32,  // float — cycles per second; 0 freezes it, negative reverses
}
@group(1) @binding(0) var<uniform> params: Params;

// Clamp-to-edge: a sample from outside the frame repeats the edge.
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

// A smooth, non-repeating-looking field in -1..1 from two layers of crossing
// waves; the inner sines bend the outer ones so no straight bands show.
fn field(p: vec2f, t: f32) -> vec2f {
    let x = sin(p.y * TAU + t * 1.3 + 0.8 * sin(p.x * TAU * 0.7 + t * 0.9))
          + 0.5 * sin(p.x * TAU * 1.7 - t * 1.1 + p.y * 2.1);
    let y = cos(p.x * TAU + t * 1.1 + 0.8 * cos(p.y * TAU * 0.8 - t * 0.7))
          + 0.5 * cos(p.y * TAU * 1.9 + t * 1.3 - p.x * 1.3);
    return vec2f(x, y) / 1.5;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let p = uv * vec2f(aspect, 1.0) / max(params.scale, 0.05);
    let t = gobofx_globals.time * params.speed * TAU * 0.25;
    let a = clamp(params.amount, 0.0, 1.0);
    let f = field(p, t);
    let off = f * a * MAX_SHIFT;
    let c = src_at(uv + off / vec2f(aspect, 1.0));
    // Caustic-like shimmer: brighter where the waves converge, darker where
    // they spread. Premultiplied, so only rgb is scaled.
    let shimmer = 1.0 + 0.12 * a * (f.x + f.y);
    return vec4f(c.rgb * max(shimmer, 0.0), c.a);
}
