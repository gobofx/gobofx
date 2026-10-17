// Hue/Saturation — rotate the hue, scale saturation and brightness.
struct Params {
    hue: f32,        // float — degrees of rotation
    saturation: f32, // float — 1 neutral
    value: f32,      // float — 1 neutral
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

// Rotate RGB about the grey axis (Rodrigues' formula): a hue shift that keeps luma roughly.
fn hue_rotate(c: vec3f, deg: f32) -> vec3f {
    let a = radians(deg);
    let k = vec3f(0.57735);
    let cs = cos(a);
    return c * cs + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - cs);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    var c = unpremultiply(src);
    c = hue_rotate(c, params.hue);
    c = mix(vec3f(luma(c)), c, params.saturation);
    c = max(c * params.value, vec3f(0.0));
    return vec4f(c * src.a, src.a);
}
