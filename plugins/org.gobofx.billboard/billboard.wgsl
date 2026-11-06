// Billboard — the frame is a row of vertical slats, `from` on one face and
// `to` on the other; each slat turns about its own axis, left to right.
struct Params {
    count: i32,       // int — slats across the frame
    stagger: f32,     // float — 0 all slats turn together … 1 a wave from the left
    perspective: f32, // float — foreshortening of a turning slat
    ease: f32,        // float
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

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let n = f32(clamp(params.count, 2, 24));
    let gx = uv.x * n;
    let slat = floor(gx);
    let lx = fract(gx) - 0.5;
    let order = slat / (n - 1.0);
    let st = clamp(params.stagger, 0.0, 1.0);
    let lt = clamp(t * (1.0 + st) - order * st, 0.0, 1.0);
    let theta = lt * 3.14159265;
    let c = cos(theta);
    let s = sin(theta);
    if (abs(c) < 1e-4) { return vec4f(0.0); } // edge-on: the gap behind the slat
    let u = lx / c;
    if (abs(u) > 0.5) { return vec4f(0.0); }
    // The near edge of a turning slat looks taller.
    let k = clamp(params.perspective, 0.0, 1.0) * 0.8;
    let v = (uv.y - 0.5) / (1.0 + k * u * s);
    if (abs(v) > 0.5) { return vec4f(0.0); }
    if (c > 0.0) {
        return from_at(vec2f((slat + u + 0.5) / n, v + 0.5));
    }
    // Back face, mirrored about the slat's axis so `to` reads correctly once flat.
    return to_at(vec2f((slat + 0.5 - u) / n, v + 0.5));
}
