// Sharpen — unsharp mask: add back the difference between the picture and
// a blurred copy. Three passes: blur H, blur V, combine.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 16.0;

struct Params {
    amount: f32, // float — strength
    radius: f32, // float — pixels, the scale of detail that gets sharpened
}
@group(1) @binding(0) var<uniform> params: Params;

@fragment
fn fs_blur(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = clamp(params.radius, 0.5, MAX_RADIUS);
    let sigma = r / 2.0;
    let inv = 1.0 / (2.0 * sigma * sigma);
    let dir = vec2f(DIR_X, DIR_Y) * gobofx_globals.texel;
    let n = i32(ceil(r));
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

@fragment
fn fs_combine(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let blur = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let o = src.rgb + (src.rgb - blur.rgb) * clamp(params.amount, 0.0, 4.0);
    return vec4f(clamp(o, vec3f(0.0), vec3f(src.a) + 1.0), src.a); // keep premultiplied sane, allow HDR
}
