// Gaussian Blur — separable, two passes (horizontal, then vertical).
// The pass direction comes from pipeline-overridable constants set per pass
// in the manifest. Sigma = radius / 3, so the kernel covers ±3σ.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 64.0;

struct Params {
    radius: f32, // float — pixels
}
@group(1) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = clamp(params.radius, 0.0, MAX_RADIUS);
    if (r < 0.5) {
        return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
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
        acc += textureSampleLevel(gobofx_input0, gobofx_sampler, uv + dir * x, 0.0) * w;
        wsum += w;
    }
    return acc / wsum;
}
