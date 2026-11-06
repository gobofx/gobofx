// Channel Mixer — every output channel is a weighted sum of the three input
// channels, in linear light. Nine weights, one row per output channel; the
// unit matrix is a no-op. Monochrome writes the red row's mix to all three
// channels, the classic way to make a black-and-white from chosen weights.
struct Params {
    red_red: f32,     // float — row 1: red out = rr * r + rg * g + rb * b
    red_green: f32,   // float
    red_blue: f32,    // float
    green_red: f32,   // float — row 2
    green_green: f32, // float
    green_blue: f32,  // float
    blue_red: f32,    // float — row 3
    blue_green: f32,  // float
    blue_blue: f32,   // float
    monochrome: u32,  // bool — 1: the red row feeds all three channels
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let c = unpremultiply(src);
    let row_r = vec3f(params.red_red, params.red_green, params.red_blue);
    let row_g = vec3f(params.green_red, params.green_green, params.green_blue);
    let row_b = vec3f(params.blue_red, params.blue_green, params.blue_blue);
    let r = dot(row_r, c);
    var o = vec3f(r, dot(row_g, c), dot(row_b, c));
    if (params.monochrome == 1u) {
        o = vec3f(r);
    }
    o = max(o, vec3f(0.0));
    return vec4f(o * src.a, src.a);
}
