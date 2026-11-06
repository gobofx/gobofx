// Wave — sine-wave displacement, animated.
struct Params {
    amplitude: f32,  // float — in frame heights
    wavelength: f32, // float — in frame heights
    direction: u32,  // choice — 0 horizontal waves (displace x by y), 1 vertical, 2 both
    phase: f32,      // float — degrees
    speed: f32,      // float — cycles per second
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
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let p = uv * vec2f(aspect, 1.0);
    let k = 6.28318530718 / max(params.wavelength, 0.05);
    let ph = radians(params.phase) + gobofx_globals.time * params.speed * 6.28318530718;
    let amp = params.amplitude;
    var off = vec2f(0.0);
    if (params.direction == 0u || params.direction == 2u) { off.x += sin(p.y * k + ph) * amp; }
    if (params.direction == 1u || params.direction == 2u) { off.y += sin(p.x * k + ph) * amp; }
    return src_at(uv + off / vec2f(aspect, 1.0));
}
