// Flop — mirror the picture horizontally, vertically or both.
struct Params {
    mode: u32, // choice — 0 horizontal, 1 vertical, 2 both
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
    var p = uv;
    if (params.mode == 0u || params.mode == 2u) { p.x = 1.0 - p.x; }
    if (params.mode == 1u || params.mode == 2u) { p.y = 1.0 - p.y; }
    return src_at(p);
}
