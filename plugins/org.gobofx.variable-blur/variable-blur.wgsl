// Variable Blur — sharp at a point, blur growing with distance from it. A
// separable Gaussian in two passes with a per-pixel radius: 0 inside the
// inner radius, ramping to the full radius at the outer one. Max Blur 0
// passes through.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 48.0;

struct Params {
    center: vec2f, // point — the sharp spot
    inner: f32,    // float — radius that stays sharp, in frame heights
    outer: f32,    // float — radius where the blur reaches its maximum
    radius: f32,   // float — the blur radius in pixels at the outer radius and beyond
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

// 0 at the centre out to the inner radius, 1 from the outer radius on, in
// frame heights so the falloff is round at any aspect.
fn blur_amount(uv: vec2f) -> f32 {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = length((uv - params.center) * vec2f(aspect, 1.0));
    let lo = clamp(params.inner, 0.0, 2.0);
    let hi = max(clamp(params.outer, 0.05, 2.0), lo + 1e-3);
    return smoothstep(lo, hi, d);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = clamp(params.radius, 0.0, MAX_RADIUS) * blur_amount(uv);
    if (r < 0.5) {
        return src_at(uv);
    }
    let sigma = r / 3.0;
    let inv_two_sigma2 = 1.0 / (2.0 * sigma * sigma);
    let dir = vec2f(DIR_X, DIR_Y) * gobofx_globals.texel;
    let n = i32(ceil(r));
    var acc = vec4f(0.0);
    var wsum = 0.0;
    for (var i = -n; i <= n; i++) {
        let x = f32(i);
        let w = exp(-x * x * inv_two_sigma2);
        acc += src_at(uv + dir * x) * w;
        wsum += w;
    }
    return acc / wsum;
}
