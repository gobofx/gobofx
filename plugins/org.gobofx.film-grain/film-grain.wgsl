// Film Grain — animated noise, stronger in the midtones and shadows.
struct Params {
    amount: f32,  // float — strength
    size: f32,    // float — grain size in pixels
    color: u32,   // bool — 0 monochrome grain, 1 per-channel
    shadows: f32, // float — how much the grain favours darker tones
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
    let c = unpremultiply(src);
    let frame = floor(gobofx_globals.time * 24.0);
    let cell = floor(uv * gobofx_globals.resolution / max(params.size, 1.0)) + vec2f(frame * 3.1, frame * 7.3);
    var n: vec3f;
    if (params.color == 1u) {
        n = vec3f(hash21(cell), hash21(cell + 11.0), hash21(cell + 23.0)) - 0.5;
    } else {
        n = vec3f(hash21(cell) - 0.5);
    }
    let y = luma(c);
    // Shadows 0: even grain; 1: almost none in the highlights, full in the blacks.
    let weight = pow(clamp(1.0 - y, 0.0, 1.0), clamp(params.shadows, 0.0, 1.0) * 3.0);
    let o = max(c + n * clamp(params.amount, 0.0, 1.0) * 0.2 * weight, vec3f(0.0));
    return vec4f(o * src.a, src.a);
}
