// Tint — a monochrome in one colour: the picture becomes its luma times the
// colour, in linear light, so white becomes the colour itself and black stays
// black. Amount blends back to the original; 0 is a no-op.
struct Params {
    color: vec4f, // color — the single colour of the monochrome (premultiplied, as all colour params)
    amount: f32,  // float — 0 original .. 1 fully tinted
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

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let c = unpremultiply(src);
    let mono = max(luma(c), 0.0) * unpremultiply(params.color);
    let o = max(mix(c, mono, clamp(params.amount, 0.0, 1.0)), vec3f(0.0));
    return vec4f(o * src.a, src.a);
}
