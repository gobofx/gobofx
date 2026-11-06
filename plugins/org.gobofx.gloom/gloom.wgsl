// Gloom — a dark glow: the shadows bleed outward and pull their
// surroundings down, the inverse of Bloom. Pass 1 keeps what is below the
// threshold as a coverage mask, two passes blur it, pass 4 multiplies the
// source down by it. Intensity 0 passes through.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 64.0;

struct Params {
    threshold: f32, // float — brightness below which a pixel counts as dark
    radius: f32,    // float — spread in pixels
    intensity: f32, // float — how far the darks pull their neighbours down
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
fn fs_dark(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let y = luma(unpremultiply(src));
    let t = clamp(params.threshold, 0.0, 1.0);
    // Soft knee below the threshold; the edges are kept apart so a threshold
    // of 0 is a valid (empty) mask rather than a 0/0.
    let lo = t * 0.6;
    let hi = max(t, lo + 1e-3);
    let k = (1.0 - smoothstep(lo, hi, y)) * src.a;
    // Only the coverage matters downstream; carried as black with alpha.
    return vec4f(0.0, 0.0, 0.0, k);
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
fn fs_apply(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let g = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0).a;
    let k = clamp(params.intensity, 0.0, 1.5);
    let keep = max(1.0 - g * k, 0.0);
    return vec4f(src.rgb * keep, src.a);
}
