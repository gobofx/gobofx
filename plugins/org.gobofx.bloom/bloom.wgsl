// Bloom — the highlights bleed into their surroundings, as light does in a
// lens. Four passes: a bright pass with a soft knee, a wide separable
// Gaussian, then the tinted haze is added back. Intensity 0 passes through.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 64.0;

struct Params {
    threshold: f32, // float — brightness where the bleed starts
    radius: f32,    // float — spread in pixels
    intensity: f32, // float — strength of the haze
    tint: vec4f,    // color — the haze's colour (white keeps the source hue)
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_bright(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let y = luma(unpremultiply(src));
    let t = clamp(params.threshold, 0.0, 1.0);
    // The knee is a fixed third of the threshold: bloom should roll in, not snap.
    let k = smoothstep(t * 0.67, t, y);
    return src * k;
}

@fragment
fn fs_blur(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = clamp(params.radius, 1.0, MAX_RADIUS);
    // Sigma of half the radius: a wide, lazy haze rather than a tight glow.
    let sigma = r / 2.0;
    let inv = 1.0 / (2.0 * sigma * sigma);
    let dir = vec2f(DIR_X, DIR_Y) * gobofx_globals.texel;
    let n = i32(ceil(r));
    var acc = vec4f(0.0);
    var wsum = 0.0;
    for (var i = -n; i <= n; i++) {
        let x = f32(i);
        let w = exp(-x * x * inv);
        acc += src_at(uv + dir * x) * w;
        wsum += w;
    }
    return acc / wsum;
}

@fragment
fn fs_add(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let haze = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let k = clamp(params.intensity, 0.0, 3.0);
    let tint = unpremultiply(params.tint) * params.tint.a;
    let a = clamp(src.a + haze.a * k, 0.0, 1.0);
    return vec4f(src.rgb + haze.rgb * tint * k, a);
}
