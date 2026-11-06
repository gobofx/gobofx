// Levels — black point, white point and gamma, then a per-channel offset.
// The controls read on the display scale (gamma 2.2): a black point of 0.1
// means "10 % grey becomes black", as a waveform would show it. The maths
// happens in that encoding and the result goes back to linear light.
// Defaults are a no-op.
struct Params {
    black: f32, // float — input level that becomes black
    white: f32, // float — input level that becomes white
    gamma: f32, // float — 1 is neutral; above 1 lifts the midtones
    red: f32,   // float — added to the red channel after the remap
    green: f32, // float — added to the green channel
    blue: f32,  // float — added to the blue channel
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}
fn encode(c: vec3f) -> vec3f {
    return pow(max(c, vec3f(0.0)), vec3f(1.0 / 2.2));
}
fn decode(c: vec3f) -> vec3f {
    return pow(max(c, vec3f(0.0)), vec3f(2.2));
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    var c = encode(unpremultiply(src));
    let b = clamp(params.black, 0.0, 0.95);
    let w = max(clamp(params.white, 0.05, 1.0), b + 0.01);
    c = max((c - b) / (w - b), vec3f(0.0));
    c = pow(c, vec3f(1.0 / clamp(params.gamma, 0.2, 5.0)));
    c = max(c + vec3f(params.red, params.green, params.blue), vec3f(0.0));
    return vec4f(decode(c) * src.a, src.a);
}
