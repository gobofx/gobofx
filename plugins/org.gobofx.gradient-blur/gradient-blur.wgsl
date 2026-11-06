// Gradient Blur — a tilt-shift ramp: one sharp band across the frame, the
// blur growing with distance from it. Separable Gaussian in two passes with a
// per-pixel sigma, so the band's edge feathers smoothly. Radius 0 passes
// through.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 48.0;

struct Params {
    position: f32, // float — where the sharp band sits along the axis, 0..1
    width: f32,    // float — the band's width as a fraction of the frame
    feather: f32,  // float — how far past the band the blur ramps up, 0..1
    radius: f32,   // float — blur radius in pixels, reached past the feather
    angle: f32,    // float — band angle in degrees, 0 horizontal
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

// 0 inside the sharp band, 1 past the feather. The axis is measured in
// frame fractions, so the band position means the same at any aspect.
fn blur_amount(uv: vec2f) -> f32 {
    let a = radians(params.angle);
    let n = vec2f(-sin(a), cos(a));
    let d = abs(dot(uv - vec2f(0.5), n) + 0.5 - clamp(params.position, 0.0, 1.0));
    let half = clamp(params.width, 0.0, 1.0) * 0.5;
    let f = max(clamp(params.feather, 0.0, 1.0), 1e-3);
    return smoothstep(half, half + f, d);
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
