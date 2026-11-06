// Noise Dissolve — eat the picture away to transparent through a field of
// random grains: at `amount` 0 nothing is gone, at 1 everything is.
struct Params {
    amount: f32,   // float — fraction dissolved, 0 is the source, 1 is fully transparent
    size: f32,     // float — px; grain size
    softness: f32, // float — 0 is a hard per-grain cut, 1 fades each grain over the whole range
    seed: i32,     // int — picks a different grain field
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
    let size = clamp(params.size, 1.0, 32.0);
    let cell = floor(uv * gobofx_globals.resolution / size) + vec2f(f32(params.seed) * 13.7, f32(params.seed) * 5.3);
    let n = hash21(cell);
    // The threshold runs from -soft to 1 + soft as amount goes 0 → 1, so the
    // first grain goes only after 0 and the last is gone exactly at 1.
    let soft = max(clamp(params.softness, 0.0, 1.0) * 0.5, 1e-3);
    let t = mix(-soft, 1.0 + soft, clamp(params.amount, 0.0, 1.0));
    let keep = smoothstep(t - soft, t + soft, n);
    return src * keep;
}
