// Color Adjustments — exposure, contrast, saturation, temperature and tint
// in one pass, in linear light. Defaults are a no-op.
struct Params {
    exposure: f32,    // float — stops
    contrast: f32,    // float — around 18 % grey; 1 is neutral
    saturation: f32,  // float — 1 is neutral
    temperature: f32, // float — negative cool, positive warm
    tint: f32,        // float — negative green, positive magenta
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
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    var c = unpremultiply(src);
    c *= exp2(params.exposure);
    let t = params.temperature;
    let g = params.tint;
    c *= vec3f(1.0 + 0.25 * t - 0.1 * g, 1.0 - 0.2 * g, 1.0 - 0.25 * t - 0.1 * g);
    c = mix(vec3f(0.18), c, params.contrast);
    c = mix(vec3f(luma(c)), c, params.saturation);
    c = max(c, vec3f(0.0));
    return vec4f(c * src.a, src.a);
}
