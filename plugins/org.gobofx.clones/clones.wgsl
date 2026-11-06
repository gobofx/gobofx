// Clones — `from` multiplies into a grid of copies of itself, which then
// shrink away one by one to leave `to`.
struct Params {
    count: i32, // int — copies across and down at the midpoint
    gap: f32,   // float — gutter between the copies, as a fraction of a cell
    ease: f32,  // float
}
@group(1) @binding(0) var<uniform> params: Params;

fn from_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0), inside);
}
fn to_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0), inside);
}
fn eased(ease: f32) -> f32 {
    let p = clamp(gobofx_globals.progress, 0.0, 1.0);
    return mix(p, smoothstep(0.0, 1.0, p), clamp(ease, 0.0, 1.0));
}
// Premultiplied `over`.
fn over(top: vec4f, bottom: vec4f) -> vec4f {
    return top + bottom * (1.0 - top.a);
}
fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let ph1 = clamp(t * 2.0, 0.0, 1.0);       // multiply
    let ph2 = clamp(t * 2.0 - 1.0, 0.0, 1.0); // shrink away
    let count = f32(clamp(params.count, 2, 8));
    // The repeat count grows continuously from 1; the half-cell phase keeps the
    // grid centred and lands its cell edges on the frame edges at every integer.
    let n = mix(1.0, count, ph1);
    let phase = 0.25 * (1.0 - cos(3.14159265 * n));
    let g = (uv - 0.5) * n - phase;
    let cell = floor(g);
    let local = fract(g);
    let gutter = clamp(params.gap, 0.0, 0.4) * 0.5 * ph1;
    // Each copy shrinks to its centre on its own slightly delayed clock.
    let delay = hash21(cell + 0.5) * 0.4;
    let lt = clamp((ph2 - delay) / 0.6, 0.0, 1.0);
    let e = (0.5 - gutter) * (1.0 - lt); // half-extent of the copy inside its cell
    let bg = to_at(uv) * smoothstep(0.25, 0.5, t);
    let q = local - 0.5;
    if (e <= 1e-5 || any(abs(q) >= vec2f(e))) {
        return bg;
    }
    let copy = from_at(0.5 + q / (2.0 * e));
    return over(copy, bg);
}
