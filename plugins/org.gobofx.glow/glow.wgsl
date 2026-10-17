// Glow — the bright parts bleed outward. Four passes: extract highlights,
// blur them horizontally and vertically, add them back.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 64.0;

struct Params {
    threshold: f32, // float — brightness where the glow starts
    softness: f32,  // float — width of the knee below the threshold
    radius: f32,    // float — spread in pixels
    intensity: f32, // float — strength
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
}
fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_bright(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let y = luma(src.rgb);
    let t = clamp(params.threshold, 0.0, 1.0);
    let k = smoothstep(t - clamp(params.softness, 0.0, 1.0) * t, t, y);
    return src * k;
}

@fragment
fn fs_blur(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = clamp(params.radius, 1.0, MAX_RADIUS);
    let sigma = r / 2.5;
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
fn fs_add(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let glow = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let k = clamp(params.intensity, 0.0, 3.0);
    // Screen-like add so it blooms without clipping too hard; alpha grows where the glow spills.
    let a = clamp(src.a + glow.a * k, 0.0, 1.0);
    return vec4f(src.rgb + glow.rgb * k, a);
}
