// Directional Blur — motion blur along one angle.
const SAMPLES: i32 = 32;

struct Params {
    angle: f32,  // float — degrees, 0 horizontal
    length: f32, // float — total streak length in pixels
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
    let len = clamp(params.length, 0.0, 200.0);
    if (len < 0.5) { return src_at(uv); }
    let a = radians(params.angle);
    let dir = vec2f(cos(a), sin(a)) * gobofx_globals.texel * len;
    let j = hash21(uv * gobofx_globals.resolution); // per-pixel jitter hides the steps
    var acc = vec4f(0.0);
    for (var i = 0; i < SAMPLES; i++) {
        let k = (f32(i) + j) / f32(SAMPLES) - 0.5;
        acc += src_at(uv + dir * k);
    }
    return acc / f32(SAMPLES);
}
