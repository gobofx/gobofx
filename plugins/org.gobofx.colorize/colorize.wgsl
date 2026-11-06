// Colorize — a duotone: the picture's brightness picks a point between two
// colours, blacks at one end and whites at the other. Brightness is read on
// the display scale so the ramp looks even on a monitor; the blend between
// the colours and the mix with the original happen in linear light.
struct Params {
    color_a: vec4f, // color — what black becomes (premultiplied, as all colour params)
    color_b: vec4f, // color — what white becomes
    amount: f32,    // float — 0 original .. 1 duotone
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
    let t = clamp(pow(max(luma(c), 0.0), 1.0 / 2.2), 0.0, 1.0);
    let tone = mix(unpremultiply(params.color_a), unpremultiply(params.color_b), t);
    let o = max(mix(c, tone, clamp(params.amount, 0.0, 1.0)), vec3f(0.0));
    return vec4f(o * src.a, src.a);
}
