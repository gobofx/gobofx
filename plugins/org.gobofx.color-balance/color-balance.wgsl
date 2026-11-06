// Color Balance — push the shadows, midtones and highlights each towards a
// colour, the three-slider way: cyan-red, magenta-green, yellow-blue per
// range. Each pixel's tonal range is weighted from its display-scale luma,
// the three weights sum to one, and the offsets are applied in that
// encoding, so a shadow shift lifts the blacks the way a lift wheel does.
// Defaults are a no-op.
struct Params {
    shadows_red: f32,      // float — -1 cyan .. 1 red
    shadows_green: f32,    // float — -1 magenta .. 1 green
    shadows_blue: f32,     // float — -1 yellow .. 1 blue
    midtones_red: f32,     // float
    midtones_green: f32,   // float
    midtones_blue: f32,    // float
    highlights_red: f32,   // float
    highlights_green: f32, // float
    highlights_blue: f32,  // float
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
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
    let y = clamp(luma(c), 0.0, 1.0);
    // Three weights that partition the tonal range: shadows fade out by mid
    // grey, highlights fade in from it, midtones take what is left.
    let sh = 1.0 - smoothstep(0.0, 0.5, y);
    let hi = smoothstep(0.5, 1.0, y);
    let mid = 1.0 - sh - hi;
    let shift = sh * vec3f(params.shadows_red, params.shadows_green, params.shadows_blue)
        + mid * vec3f(params.midtones_red, params.midtones_green, params.midtones_blue)
        + hi * vec3f(params.highlights_red, params.highlights_green, params.highlights_blue);
    // Full scale is half the display range: enough to go wrong, not absurd.
    let o = decode(c + clamp(shift, vec3f(-1.0), vec3f(1.0)) * 0.5);
    return vec4f(o * src.a, src.a);
}
