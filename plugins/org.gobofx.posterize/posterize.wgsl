// Posterize — reduce the picture to a few tonal levels.
struct Params {
    levels: i32,      // int — steps per channel
    gamma: f32,       // float — quantise in this perceptual space (2.2 ≈ display)
    per_channel: u32, // bool — 0 quantise brightness only, 1 each channel
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
    let c = max(unpremultiply(src), vec3f(0.0));
    let n = f32(clamp(params.levels, 2, 64)) - 1.0;
    let g = clamp(params.gamma, 0.5, 3.0);
    var o: vec3f;
    if (params.per_channel == 1u) {
        let p = pow(c, vec3f(1.0 / g));
        o = pow(round(p * n) / n, vec3f(g));
    } else {
        let y = luma(c);
        let yq = pow(round(pow(y, 1.0 / g) * n) / n, g);
        o = c * (yq / max(y, 1e-5));
    }
    return vec4f(o * src.a, src.a);
}
