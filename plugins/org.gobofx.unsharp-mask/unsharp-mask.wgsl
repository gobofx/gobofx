// Unsharp Mask — the classic darkroom sharpen with a threshold: blur a copy,
// take the difference, and add it back only where the local contrast is
// above the threshold, so edges get crisper while flat skin and sky, and
// their noise, stay as they were. Three passes: blur H, blur V, combine.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 32.0;

struct Params {
    amount: f32,    // float — strength; 0 is a no-op
    radius: f32,    // float — pixels, the scale of detail that is enhanced
    threshold: f32, // float — display-scale local contrast below which nothing is sharpened
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn encode(c: vec3f) -> vec3f {
    return pow(max(c, vec3f(0.0)), vec3f(1.0 / 2.2));
}

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
    // Local contrast on the display scale, the largest channel difference
    // between the picture and its blur, so the threshold reads like a level.
    let d = abs(encode(unpremultiply(src)) - encode(unpremultiply(blur)));
    let contrast = max(d.r, max(d.g, d.b));
    let t = clamp(params.threshold, 0.0, 1.0);
    // Soft knee above the threshold so the gate does not posterise the edges.
    let gate = smoothstep(t, t + max(0.5 * t, 0.01), contrast);
    let o = src.rgb + (src.rgb - blur.rgb) * clamp(params.amount, 0.0, 4.0) * gate;
    return vec4f(clamp(o, vec3f(0.0), vec3f(src.a) + 1.0), src.a); // keep premultiplied sane, allow HDR
}
