// Overdrive — a blown-out glow. The source is pushed up by a pre-gain
// before the bright pass, so far more of the picture counts as highlight,
// the result is blurred wide and added back, and the sum is clipped hard at
// white: the brights crush to a flat hot core with a halo. Four passes;
// intensity 0 passes through.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 64.0;

struct Params {
    pre_gain: f32,  // float — multiplier on the source before the threshold
    threshold: f32, // float — brightness (after gain) where the glow starts
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
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_bright(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let c = unpremultiply(src) * clamp(params.pre_gain, 1.0, 8.0);
    let y = luma(c);
    let t = clamp(params.threshold, 0.0, 1.0);
    let lo = t * 0.8;
    let hi = max(t, lo + 1e-3);
    let k = smoothstep(lo, hi, y) * src.a;
    // Premultiplied; the gained colour may exceed alpha, that is the point.
    return vec4f(c * k, k);
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
        acc += src_at(uv + dir * x) * w;
        wsum += w;
    }
    return acc / wsum;
}

@fragment
fn fs_add(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let glow = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let k = clamp(params.intensity, 0.0, 3.0);
    let a = clamp(src.a + glow.a * k, 0.0, 1.0);
    // Clipped hot: nothing brighter than white at this pixel's coverage.
    let rgb = min(src.rgb + glow.rgb * k, vec3f(a));
    return vec4f(rgb, a);
}
