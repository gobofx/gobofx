// Spin — `from` spins and shrinks away into `to`.
struct Params {
    turns: f32,    // float — full rotations over the transition
    zoom: f32,     // float — 0 keeps `from` full size (fades instead), 1 shrinks it to nothing
    center: vec2f, // point
    ease: f32,     // float
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
// Direction 0..3 → the axis coordinate that grows along the wipe.
fn axis(uv: vec2f, direction: u32) -> f32 {
    switch direction {
        case 1u: { return 1.0 - uv.x; }
        case 2u: { return uv.y; }
        case 3u: { return 1.0 - uv.y; }
        default: { return uv.x; }
    }
}
fn dir_vec(direction: u32) -> vec2f {
    switch direction {
        case 1u: { return vec2f(-1.0, 0.0); }
        case 2u: { return vec2f(0.0, 1.0); }
        case 3u: { return vec2f(0.0, -1.0); }
        default: { return vec2f(1.0, 0.0); }
    }
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let ang = t * params.turns * 6.28318530718;
    let s = max(1.0 - clamp(params.zoom, 0.0, 1.0) * t, 1e-4);
    var d = (uv - params.center) * vec2f(aspect, 1.0);
    d = vec2f(d.x * cos(ang) + d.y * sin(ang), -d.x * sin(ang) + d.y * cos(ang)) / s;
    let src = params.center + d / vec2f(aspect, 1.0);
    // Fade at the end so a `zoom` of 0 still lands on `to`.
    let keep = 1.0 - smoothstep(0.7, 1.0, t) * (1.0 - clamp(params.zoom, 0.0, 1.0)) - step(1.0, t);
    let a = from_at(src) * clamp(keep, 0.0, 1.0);
    return over(a, b);
}
