// Blur Dissolve — `from` blurs out while `to` blurs in, crossfading through
// the softest point at the cut. Separable Gaussian, two passes per side.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 64.0;

struct Params {
    radius: f32, // float — peak blur in pixels
    ease: f32,   // float
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

fn blur(uv: vec2f, r: f32) -> vec4f {
    if (r < 0.5) {
        return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    }
    let sigma = r / 3.0;
    let inv = 1.0 / (2.0 * sigma * sigma);
    let dir = vec2f(DIR_X, DIR_Y) * gobofx_globals.texel;
    let n = i32(ceil(min(r, MAX_RADIUS)));
    var acc = vec4f(0.0);
    var wsum = 0.0;
    for (var i = -n; i <= n; i++) {
        let x = f32(i);
        let w = exp(-x * x * inv);
        acc += textureSampleLevel(gobofx_input0, gobofx_sampler, uv + dir * x, 0.0) * w;
        wsum += w;
    }
    return acc / wsum;
}

// `from` blurs up to the full radius at t = 1 (it is gone by then anyway).
@fragment
fn fs_blur_from(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    return blur(uv, clamp(params.radius, 0.0, MAX_RADIUS) * t);
}
// `to` starts fully blurred and sharpens to 0 at t = 1.
@fragment
fn fs_blur_to(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    return blur(uv, clamp(params.radius, 0.0, MAX_RADIUS) * (1.0 - t));
}
@fragment
fn fs_mix(@location(0) uv: vec2f) -> @location(0) vec4f {
    let a = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    return mix(a, b, eased(params.ease));
}
