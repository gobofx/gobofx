// Gamma — bend the midtones with a power curve, master and per channel.
// Black and white stay where they are. The curve is applied on the display
// scale (gamma 2.2), the way a monitor gamma control reads, then the result
// goes back to linear light. 1 is neutral everywhere; above 1 lifts the
// midtones, below 1 sinks them, as on Levels.
struct Params {
    gamma: f32, // float — master, 1 neutral
    red: f32,   // float — per-channel, multiplied with the master
    green: f32, // float
    blue: f32,  // float
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
    let c = encode(unpremultiply(src));
    let per = vec3f(params.red, params.green, params.blue);
    let g = clamp(clamp(params.gamma, 0.2, 5.0) * clamp(per, vec3f(0.2), vec3f(5.0)), vec3f(0.04), vec3f(25.0));
    let o = pow(c, 1.0 / g);
    return vec4f(decode(o) * src.a, src.a);
}
