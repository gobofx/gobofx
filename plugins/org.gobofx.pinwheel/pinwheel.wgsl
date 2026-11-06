// Pinwheel — blades sweep around the centre, each revealing `to` in its own
// sector, while the whole wheel turns.
const TAU: f32 = 6.28318530718;

struct Params {
    blades: i32,   // int — sectors
    spin: f32,     // float — extra turns of the whole wheel over the transition
    softness: f32, // float — feather of each blade's edge, as a fraction of its sector
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
    let a = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let p = (uv - 0.5) * vec2f(aspect, 1.0);
    var ang = 0.0;
    if (dot(p, p) > 1e-10) { ang = atan2(p.y, p.x); }
    ang += clamp(params.spin, 0.0, 1.0) * t * TAU;
    let n = f32(clamp(params.blades, 2, 12));
    let local = fract(ang / TAU * n); // 0..1 across the blade's sector
    let soft = max(clamp(params.softness, 0.0, 0.5), 1e-4);
    // Sweeps from 0 to 1 + soft so the last sliver is fully `to` at t = 1.
    let k = clamp((t * (1.0 + soft) - local) / soft, 0.0, 1.0);
    return mix(a, b, k);
}
